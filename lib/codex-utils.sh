#!/bin/bash
# Codex CLI utilities — mirrors claude-utils.sh for the Codex backend

# Check if Codex CLI is installed and authenticated
check_codex() {
    if ! command -v codex &> /dev/null; then
        error_exit "Codex CLI not found. Install: npm install -g @openai/codex"
    fi

    local codex_version
    codex_version=$(codex --version 2>/dev/null || true)
    if [[ -z "${codex_version//[[:space:]]/}" ]]; then
        warn "Codex CLI found, but --version returned an empty string (CLI may be misinstalled)"
    else
        success "Codex CLI found: $codex_version"
    fi

    # Probe authentication. Prefer `codex login status` (zero-token, purpose-built)
    # over running a real `codex exec` call. The old probe burned ~28K codex tokens
    # per claudux invocation on a throwaway "echo hello" prompt — wasted compute
    # before any real work started.
    local probe_out probe_rc
    if codex login status --help &> /dev/null; then
        # Modern codex CLI (login subcommand exists). Zero-token probe.
        probe_out=$(codex login status 2>&1) || probe_rc=$?
        probe_rc=${probe_rc:-0}
        if [[ $probe_rc -ne 0 ]] || ! echo "$probe_out" | grep -qiE 'logged in|authenticated'; then
            error_exit "Codex CLI is not authenticated. Run 'codex login' to log in, or set OPENAI_API_KEY."
        fi
    else
        # Legacy codex CLI without `login status` subcommand. Fall back to an
        # exec probe but flag it so users upgrade.
        warn "codex CLI lacks 'login status' subcommand — falling back to exec probe (wastes ~28K tokens). Upgrade: npm install -g @openai/codex"
        probe_out=$(codex exec -m "${CODEX_MODEL:-gpt-5.4}" --json 'echo hello' 2>&1) || probe_rc=$?
        probe_rc=${probe_rc:-0}
        if [[ $probe_rc -ne 0 ]]; then
            if echo "$probe_out" | grep -qiE 'auth|api.key|unauthorized|401|login|token'; then
                error_exit "Codex CLI is not authenticated. Run 'codex login' to log in, or set OPENAI_API_KEY."
            fi
            warn "Codex CLI probe returned exit code $probe_rc (may be transient)"
        fi
    fi

    info "Using Codex backend (CLAUDUX_BACKEND=codex)"
}

# Get model name and settings for Codex
get_codex_model_settings() {
    local model="${CODEX_MODEL:-gpt-5.4}"
    local effort="${CODEX_REASONING_EFFORT:-xhigh}"
    local model_name=""
    local timeout_msg=""

    case "$model" in
        "gpt-5.4")
            model_name="GPT-5.4 (${effort} reasoning)"
            timeout_msg="This may take 60-180 seconds with GPT-5.4 xhigh..."
            ;;
        "gpt-5.3-codex")
            model_name="GPT-5.3 Codex (${effort} reasoning)"
            timeout_msg="This should take 30-90 seconds..."
            ;;
        *)
            model_name="Codex $model (${effort} reasoning)"
            timeout_msg="Processing time varies by model..."
            ;;
    esac

    echo "$model|$model_name|$timeout_msg|$effort"
}

# Run Codex non-interactively with a prompt
# Resolve the Codex stderr log path.
#
# Defaults into per-user XDG state (not shared /tmp), and refuses to append
# through a symlink or a file owned by someone else. Codex stderr can carry
# auth failures, so on a multi-user host a predictable world-writable path is
# both a redirect target and an info leak.
codex_stderr_log_path() {
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claudux"
    mkdir -p "$state_dir"
    local path="${CODEX_STDERR_LOG:-$state_dir/codex-stderr.log}"

    if [[ -L "$path" || ( -e "$path" && ! -O "$path" ) ]]; then
        path=$(mktemp "$state_dir/codex-stderr-XXXXXX" 2>/dev/null || mktemp)
    elif [[ ! -e "$path" ]]; then
        (umask 077; : > "$path") 2>/dev/null || path=$(mktemp)
    else
        # Path exists and is owned by us, but may have been created by an older
        # claudux (or another tool) with a group/other-readable mode. Codex
        # stderr can carry auth failures, so tighten it to owner-only before we
        # append; if we can't, fall back to a fresh owner-only mktemp file.
        chmod 600 "$path" 2>/dev/null || path=$(mktemp "$state_dir/codex-stderr-XXXXXX" 2>/dev/null || mktemp)
    fi

    echo "$path"
}

# Usage: run_codex_exec "prompt text" [output_file]
# Stdout: JSONL events only.  Stderr: sent to CODEX_STDERR_LOG
# (default: ${XDG_STATE_HOME:-~/.local/state}/claudux/codex-stderr.log).
# Respects CLAUDUX_TIMEOUT (seconds). Default: 600 (10 min). Set 0 to disable.
run_codex_exec() {
    local prompt="$1"
    local output_file="${2:-}"
    local model="${CODEX_MODEL:-gpt-5.4}"
    local effort="${CODEX_REASONING_EFFORT:-xhigh}"
    local stderr_log
    stderr_log="$(codex_stderr_log_path)"
    local timeout_secs="${CLAUDUX_TIMEOUT:-600}"
    # Docs generation only ever writes inside the project, so the default stays
    # workspace-scoped. Prompts are built from whatever repo the user points
    # claudux at; full-filesystem write is far more authority than the job needs.
    local sandbox_mode="${CODEX_SANDBOX_MODE:-workspace-write}"

    if [[ "${CLAUDUX_SECTION_PATCH_MODE:-}" == "1" ]]; then
        sandbox_mode="${CODEX_SANDBOX_MODE:-read-only}"
    fi

    local codex_args=(
        exec
        -m "$model"
        -c "model_reasoning_effort=\"$effort\""
        -c "approval_policy=\"never\""
        -c "sandbox_mode=\"$sandbox_mode\""
        --json
    )

    if [[ -n "$output_file" ]]; then
        codex_args+=(-o "$output_file")
    fi

    # Pass prompt via stdin; redirect stderr to log to keep stdout as clean JSONL
    if [[ "$timeout_secs" -gt 0 ]] 2>/dev/null && command -v timeout >/dev/null 2>&1; then
        echo "$prompt" | timeout "$timeout_secs" codex "${codex_args[@]}" 2>>"$stderr_log"
    elif [[ "$timeout_secs" -gt 0 ]] 2>/dev/null && command -v gtimeout >/dev/null 2>&1; then
        # macOS with coreutils installed via brew
        echo "$prompt" | gtimeout "$timeout_secs" codex "${codex_args[@]}" 2>>"$stderr_log"
    else
        echo "$prompt" | codex "${codex_args[@]}" 2>>"$stderr_log"
    fi
    local rc=$?
    # Exit code 124 from timeout/gtimeout means the command timed out
    if [[ $rc -eq 124 ]]; then
        echo '{"type":"error","message":"Codex execution timed out after '"$timeout_secs"'s"}' >&2
    fi
    return $rc
}

# Parse Codex JSONL output and render progress.
# Codex CLI v0.119+ emits: thread.started, turn.started, item.started,
# item.completed (with nested item.type: agent_message | command_execution),
# turn.completed.  This is completely different from Claude's stream-json.
_format_codex_output_stream_node() {
    local counts_file="$1"

    node -e '
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");

const countsFile = process.argv[1];
const clearLine = "\r\u001b[K";
let commandCount = 0;
let fileCount = 0;
let messageCount = 0;

function isRecord(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function truncate(value, limit) {
    return Array.from(value).slice(0, limit).join("");
}

function collectPaths(value, paths = []) {
    if (Array.isArray(value)) {
        for (const entry of value) {
            collectPaths(entry, paths);
        }
        return paths;
    }

    if (!isRecord(value)) {
        return paths;
    }

    for (const [key, entry] of Object.entries(value)) {
        if (key === "path" && typeof entry === "string") {
            paths.push(entry);
        } else {
            collectPaths(entry, paths);
        }
    }
    return paths;
}

function write(value) {
    process.stdout.write(value);
}

function renderEvent(event) {
    if (!isRecord(event) || typeof event.type !== "string") {
        return;
    }

    if (event.type === "thread.started") {
        if (typeof event.thread_id === "string" && event.thread_id.length > 0) {
            write(`${clearLine}Codex session: ${truncate(event.thread_id, 12)}...\n`);
        }
        return;
    }

    if (event.type === "item.started") {
        const item = isRecord(event.item) ? event.item : {};
        if (item.type === "command_execution" && typeof item.command === "string" && item.command.length > 0) {
            commandCount += 1;
            write(`${clearLine}Running [${commandCount}]: ${truncate(item.command, 100)}\n`);
        } else if (item.type === "file_change") {
            for (const filePath of collectPaths(item)) {
                if (filePath.length === 0) {
                    continue;
                }
                fileCount += 1;
                write(`${clearLine}Writing [${fileCount}]: ${path.basename(filePath)}\n`);
            }
        }
        return;
    }

    if (event.type === "item.completed") {
        const item = isRecord(event.item) ? event.item : {};
        if (item.type === "agent_message") {
            messageCount += 1;
            if (typeof item.text === "string" && item.text.length > 0) {
                write(`${clearLine}Agent: ${truncate(item.text, 120)}\n`);
            }
        } else if (
            item.type === "command_execution"
            && Number.isInteger(item.exit_code)
            && item.exit_code > 0
        ) {
            const command = typeof item.command === "string" ? item.command : "";
            write(`${clearLine}Command failed (exit ${item.exit_code}): ${truncate(command, 80)}\n`);
        }
        return;
    }

    if (event.type === "turn.completed") {
        const usage = isRecord(event.usage) ? event.usage : event;
        write(clearLine);
        if (
            Number.isInteger(usage.input_tokens)
            && usage.input_tokens >= 0
            && Number.isInteger(usage.output_tokens)
            && usage.output_tokens >= 0
        ) {
            write(`Turn complete — tokens: ${usage.input_tokens} in / ${usage.output_tokens} out\n`);
        }
    }
}

const input = readline.createInterface({
    input: process.stdin,
    crlfDelay: Infinity,
});

input.on("line", (line) => {
    let event;
    try {
        event = JSON.parse(line);
    } catch {
        return;
    }
    renderEvent(event);
});

input.on("close", () => {
    fs.writeFileSync(countsFile, `${commandCount} ${fileCount} ${messageCount}\n`);
});
' "$counts_file"
}

format_codex_output_stream() {
    local cmd_count=0
    local file_count=0
    local msg_count=0
    local parser_status=0
    local counts_file

    counts_file=$(mktemp "${TMPDIR:-/tmp}/claudux-codex-counts.XXXXXX") || return 1
    _format_codex_output_stream_node "$counts_file" || parser_status=$?

    if [[ -s "$counts_file" ]]; then
        read -r cmd_count file_count msg_count < "$counts_file"
    fi
    rm -f "$counts_file"

    printf "\r\033[K"
    if [[ $cmd_count -gt 0 ]] || [[ $msg_count -gt 0 ]] || [[ $file_count -gt 0 ]]; then
        echo ""
        success "Codex finished ($cmd_count commands, $file_count files, $msg_count messages)"
    fi

    return "$parser_status"
}
