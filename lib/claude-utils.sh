#!/bin/bash
# Claude CLI utilities and checks

# Check if Claude CLI is installed and configured
check_claude() {
    if ! command -v claude &> /dev/null; then
        error_exit "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    fi
    
    local claude_version
    claude_version=$(claude --version 2>/dev/null || true)
    if [[ -z "${claude_version//[[:space:]]/}" ]]; then
        warn "Claude Code CLI found, but --version returned an empty string (CLI may be misinstalled)"
    else
        success "Claude Code CLI found: $claude_version"
    fi
    
    # Show current model configuration. A cold CLI start can sit here for the
    # better part of a minute, so keep a ticker going (issue #122).
    info "🧠 Checking available models... (a cold CLI start can take up to a minute)"
    local model_check_pid
    model_check_pid=$(show_progress "Checking Claude CLI" 10)
    claude config get model 2>/dev/null || info "ℹ️  Using default model"
    stop_progress "$model_check_pid"
    
    # Detect and show project type
    load_project_config
    info "📁 Detected project type: $PROJECT_TYPE"
}

# Get model name and settings
get_model_settings() {
    local model="${FORCE_MODEL:-sonnet}"
    local model_name=""
    local timeout_msg=""
    local cost_estimate=""
    
    case "$model" in
        "opus")
            model_name="Claude Opus (most powerful)"
            timeout_msg="⏳ This may take 60-120 seconds with Opus..."
            cost_estimate="💰 Estimated cost: ~\$0.05 per run"
            ;;
        "sonnet")
            model_name="Claude Sonnet (fast & capable)"
            timeout_msg="⏳ This should take 30-60 seconds with Sonnet..."
            cost_estimate="💰 Estimated cost: ~\$0.01 per run"
            ;;
        *)
            model_name="Claude $model"
            timeout_msg="⏳ Processing time varies by model..."
            cost_estimate="💰 Cost varies by model"
            ;;
    esac
    
    echo "$model|$model_name|$timeout_msg|$cost_estimate"
}

# Elapsed-time heartbeat for phases that sit silent for 30-90s (issue #122).
# Ticks go to stderr so a `pid=$(show_progress ...)` call site captures only
# the PID: the previous phased version echoed to stdout inside the command
# substitution, which blocked the caller for the full ~148s sleep chain and
# swallowed every message it printed — the ticker never reached the user.
show_progress() {
    local label="${1:-Still working}"
    local interval="${2:-10}"

    # The subshell's stdout MUST be redirected away: it inherits the command
    # substitution's pipe, and merely echoing to stderr inside still holds
    # that pipe open, blocking the caller until the loop exits.
    (
        elapsed=0
        # Self-terminate eventually so a hard-killed parent can't leave an
        # orphan ticking forever; normal paths kill this PID much earlier.
        while (( elapsed < 1800 )); do
            sleep "$interval"
            elapsed=$((elapsed + interval))
            echo "⏳ ${label}... (${elapsed}s elapsed)"
        done
    ) >&2 &

    echo $!  # Return PID for later cleanup
}

# Kill a heartbeat started by show_progress; safe to call with an empty PID.
stop_progress() {
    local pid="${1:-}"
    [[ -n "$pid" ]] || return 0
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}

# Format Claude's output for better readability
format_claude_output() {
    local file_count=0
    local current_file=""
    local verbose_level=1
    
    while IFS= read -r line; do
        # Detect file operations
        if [[ "$line" =~ Writing.*to[[:space:]]+(.*) ]]; then
            current_file="${BASH_REMATCH[1]}"
            ((file_count++))
            printf "\r\033[K✅ Created [%d]: %s\n" "$file_count" "$current_file"
        elif [[ "$line" =~ Creating[[:space:]]+(.*) ]]; then
            current_file="${BASH_REMATCH[1]}"
            ((file_count++))
            printf "\r\033[K📝 Creating [%d]: %s\n" "$file_count" "$current_file"
        elif [[ "$line" =~ Reading[[:space:]]+(.*) ]]; then
            current_file="${BASH_REMATCH[1]}"
            if [[ "$verbose_level" -ge 1 ]]; then
                printf "\r\033[K🔍 Analyzing: %s\n" "$current_file"
            fi
        elif [[ "$line" =~ Updating[[:space:]]+(.*) ]]; then
            current_file="${BASH_REMATCH[1]}"
            ((file_count++))
            printf "\r\033[K📝 Updated [%d]: %s\n" "$file_count" "$current_file"
        elif [[ "$line" =~ Deleting[[:space:]]+(.*) ]]; then
            current_file="${BASH_REMATCH[1]}"
            ((file_count++))
            printf "\r\033[K🗑️  Removed [%d]: %s\n" "$file_count" "$current_file"
        elif [[ "$line" =~ "Phase 1:" ]]; then
            echo ""
            print_color "CYAN" "━━━ Phase 1: Analysis & Planning ━━━"
        elif [[ "$line" =~ "Phase 2:" ]]; then
            echo ""
            print_color "CYAN" "━━━ Phase 2: Documentation Generation ━━━"
        elif [[ "$line" =~ "Error:" ]] || [[ "$line" =~ "error:" ]]; then
            print_color "RED" "❌ $line"
        elif [[ "$line" =~ "Warning:" ]] || [[ "$line" =~ "warning:" ]]; then
            print_color "YELLOW" "⚠️  $line"
        elif [[ "$line" =~ "Success:" ]] || [[ "$line" =~ "Complete" ]]; then
            echo "✅ $line"
        elif [[ "$line" =~ ^[[:space:]]*$ ]]; then
            # Skip empty lines to reduce noise
            :
        elif [[ "$line" =~ "Tool Use:" ]] || [[ "$line" =~ "Using tool:" ]]; then
            if [[ "$verbose_level" -ge 2 ]]; then
                echo "   $line"
            fi
            :
        elif [[ "$line" =~ "Assistant:" ]]; then
            # Skip assistant markers
            :
        else
            # For other important messages, show them dimmed
            if [[ ${#line} -gt 80 ]]; then
                # Truncate long lines
                echo "   ${line:0:77}..."
            elif [[ -n "$line" ]]; then
                echo "   $line"
            fi
        fi
    done
    
    # Clear the progress line
    printf "\r\033[K"
    
    if [[ $file_count -gt 0 ]]; then
        echo ""
        success "📚 Processed $file_count files"
    fi
}

# Parse streaming JSON lines from Claude CLI and render concise progress
format_claude_output_stream() {
    local file_count=0
    local verbose_level=1
    local line
    local delta_preview_chars=180
    local printed_phase1=0
    local printed_phase2=0
    local reads=0
    local creates=0
    local updates=0
    local writes=0
    local deletes=0

    while IFS= read -r line; do
        # Emit heartbeat for init messages so users see early activity
        if echo "$line" | grep -q '"subtype"[[:space:]]*:[[:space:]]*"init"'; then
            # Try to extract model for a concise summary line
            local init_model
            init_model=$(echo "$line" | sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            if [[ -n "$init_model" ]]; then
                print_color "BLUE" "   🔄 Session started • Model: $init_model"
            else
                print_color "BLUE" "   🔄 Session started"
            fi
            if [[ $printed_phase1 -eq 0 ]]; then
                echo ""
                print_color "CYAN" "━━━ Phase 1: Analysis & Planning ━━━"
                printed_phase1=1
            fi
            continue
        fi
        if echo "$line" | grep -q '"type"[[:space:]]*:[[:space:]]*"result"'; then
            # Final result message; show brief summary if verbose
            if [[ "$verbose_level" -ge 1 ]]; then
                local turns
                turns=$(echo "$line" | sed -n 's/.*"num_turns"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p')
                local cost
                cost=$(echo "$line" | sed -n 's/.*"total_cost_usd"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p')
                [[ -n "$turns" ]] && echo "   ✅ Completed in $turns turns"
                [[ -n "$cost" ]] && echo "   💰 Cost: $cost USD"
            fi
            continue
        fi
        # Fast-path: if this doesn't look like JSON, fall back to plain formatter heuristics
        if [[ ! "$line" =~ ^\{ ]] && [[ ! "$line" =~ ^\[ ]]; then
            if [[ -n "$line" ]]; then
                echo "   $line"
            fi
            continue
        fi

        # Errors
        if echo "$line" | grep -qi '"error"'; then
            print_color "RED" "❌ $line"
            continue
        fi

        # Ignore large tool_result payloads (we already print concise tool usage lines)
        if echo "$line" | grep -q '"tool_result"'; then
            continue
        fi

        # Extract a path if present ("path" in the legacy format, "file_path" in Claude Code tool_use input)
        local path
        path=$(echo "$line" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        if [[ -z "$path" ]]; then
            path=$(echo "$line" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        fi

        # Detect file operations (read/write/create/update/delete)
        if echo "$line" | grep -qE 'file_(read|write|create|update|delete)|"action"\s*:\s*"(read|write|create|update|delete)"|"op"\s*:\s*"(read|write|create|update|delete)"'; then
            # Determine action
            local action
            action=$(echo "$line" | sed -n 's/.*"action"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            if [[ -z "$action" ]]; then
                action=$(echo "$line" | sed -n 's/.*"op"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            fi
            if [[ -z "$action" ]]; then
                if echo "$line" | grep -q 'file_create'; then action="create"; fi
                if echo "$line" | grep -q 'file_update'; then action="update"; fi
                if echo "$line" | grep -q 'file_write'; then action="write"; fi
                if echo "$line" | grep -q 'file_delete'; then action="delete"; fi
                if echo "$line" | grep -q 'file_read'; then action="read"; fi
            fi

            # Phase switching on first mutating op
            if [[ "$action" != "read" ]] && [[ $printed_phase2 -eq 0 ]]; then
                echo ""
                print_color "CYAN" "━━━ Phase 2: Documentation Generation ━━━"
                printed_phase2=1
            fi

            # Emit per-action logs and counts
            if [[ "$action" == "read" ]]; then
                ((reads++))
                if [[ -n "$path" ]]; then
                    printf "\r\033[K🔍 Analyzing: %s\n" "$path"
                else
                    printf "\r\033[K🔍 Analyzing...\n"
                fi
                continue
            fi

            if [[ -n "$path" ]]; then
                ((file_count++))
                case "$action" in
                    create) ((creates++)) ;;
                    update) ((updates++)) ;;
                    write)  ((writes++)) ;;
                    delete) ((deletes++)) ;;
                esac
                printf "\r\033[K📝 Change [%d]: %s\n" "$file_count" "$path"
                continue
            fi
        fi

        # Claude Code stream-json: count file operations from tool_use events
        # (the legacy file_(read|write|...) branch above never matches this format)
        if echo "$line" | grep -q '"type"[[:space:]]*:[[:space:]]*"tool_use"'; then
            local cc_tool
            cc_tool=$(echo "$line" | sed -nE 's/.*"name"[[:space:]]*:[[:space:]]*"(Read|Write|Edit|MultiEdit)".*/\1/p')
            if [[ -n "$cc_tool" ]]; then
                if [[ "$cc_tool" != "Read" ]] && [[ $printed_phase2 -eq 0 ]]; then
                    echo ""
                    print_color "CYAN" "━━━ Phase 2: Documentation Generation ━━━"
                    printed_phase2=1
                fi
                case "$cc_tool" in
                    Read)  ((reads++)) ;;
                    Write) ((writes++)); ((file_count++)) ;;
                    Edit|MultiEdit) ((updates++)); ((file_count++)) ;;
                esac
            fi
        fi

        # Tool usage notifications (verbose only)
        if [[ "$verbose_level" -ge 1 ]]; then
            local tool
            tool=$(echo "$line" | sed -n 's/.*"toolName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            if [[ -z "$tool" ]]; then
                tool=$(echo "$line" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            fi
            if [[ -n "$tool" ]] && echo "$line" | grep -qE 'tool|Tool|tool_use'; then
                # Build a short blurb using common fields
                local blurb=""
                local cmd query pattern glob dir startLine endLine offset limit
                cmd=$(echo "$line" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                query=$(echo "$line" | sed -n 's/.*"query"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                pattern=$(echo "$line" | sed -n 's/.*"pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                glob=$(echo "$line" | sed -n 's/.*"glob"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                dir=$(echo "$line" | sed -n 's/.*"dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
                startLine=$(echo "$line" | sed -n 's/.*"startLine"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p')
                endLine=$(echo "$line" | sed -n 's/.*"endLine"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p')
                offset=$(echo "$line" | sed -n 's/.*"offset"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p')
                limit=$(echo "$line" | sed -n 's/.*"limit"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p')

                if [[ -n "$path" ]]; then
                    blurb="file: $path"
                fi
                if [[ -n "$startLine" ]] && [[ -n "$endLine" ]]; then
                    blurb="$blurb lines: $startLine-$endLine"
                fi
                if [[ -n "$offset" ]] && [[ -n "$limit" ]]; then
                    blurb="$blurb window: $offset+$limit"
                fi
                if [[ -n "$glob" ]]; then
                    blurb="glob: $glob"
                    [[ -n "$dir" ]] && blurb="$blurb in $dir"
                fi
                if [[ -n "$pattern" ]]; then
                    blurb="pattern: $pattern"
                    [[ -n "$path" ]] && blurb="$blurb in $path"
                fi
                if [[ -n "$query" ]]; then
                    blurb="query: $query"
                fi
                if [[ -n "$cmd" ]]; then
                    blurb="cmd: $cmd"
                fi
                # Special-case: TodoWrite with todos preview/count
                if echo "$tool" | grep -qi 'todowrite'; then
                    local todos_count first_todo
                    todos_count=$(echo "$line" | grep -o '"content"' | wc -l | tr -d ' ')
                    first_todo=$(echo "$line" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
                    if [[ -n "$todos_count" ]] && [[ "$todos_count" -gt 0 ]]; then
                        blurb="todos: $todos_count"
                        if [[ -n "$first_todo" ]]; then
                            # Truncate preview
                            if [[ ${#first_todo} -gt 80 ]]; then
                                first_todo="${first_todo:0:77}..."
                            fi
                            blurb="$blurb • first: $first_todo"
                        fi
                    fi
                fi

                printf "\r\033[K"
                if [[ -n "$blurb" ]]; then
                    print_color "CYAN" "🔧 Using tool: $tool — $blurb"
                else
                    print_color "CYAN" "🔧 Using tool: $tool"
                fi
                continue
            fi
        fi

        # Text deltas: always show a short preview
        local text
        text=$(echo "$line" | sed -n 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"\n]*\)".*/\1/p')
        if [[ -n "$text" ]]; then
            # Detect Phase 2 marker from model text and synthesize banner once
            if [[ $printed_phase2 -eq 0 ]]; then
                local upper
                upper=$(echo "$text" | tr '[:lower:]' '[:upper:]')
                if echo "$upper" | grep -q 'PHASE 2'; then
                    echo ""
                    print_color "CYAN" "━━━ Phase 2: Documentation Generation ━━━"
                    printed_phase2=1
                    # Suppress the raw markdown phase header if that's what this line is
                    if echo "$upper" | grep -qE '^\s*#{0,6}\s*PHASE\s*2\b|====\s*PHASE\s*2\b|PHASE\s*2\s*:\s*EXECUTE\s*THE\s*PLAN'; then
                        continue
                    fi
                fi
            fi
            # Unescape common sequences
            text=${text//\\n/$'\n'}
            text=${text//\\t/$'\t'}
            # Truncate to preview length
            if [[ ${#text} -gt $delta_preview_chars ]]; then
                echo "   $text" | sed -E "s/^(.{0,$delta_preview_chars}).*$/   \1.../"
            else
                echo "   $text"
            fi
            continue
        fi

        # Default: suppress raw JSON lines to keep output clean
        :
    done

    # Clear progress line and print summary
    printf "\r\033[K"
    echo ""
    # Manifest section-patch mode grants the model Read only; real doc writes
    # happen later in apply_manifest_section_patches. Do not imply "0 changes"
    # when the model never had Write/Edit (wave 21 counter-defect).
    if [[ "${CLAUDUX_SECTION_PATCH_MODE:-}" == "1" ]]; then
        info "📚 Model phase: $reads read(s) (section-patch mode — writes apply after validation)"
        echo "   🔍 reads: $reads • model tools: Read-only • patches: pending apply"
    else
        success "📚 Processed $file_count changes"
        echo "   🔍 reads: $reads • 🆕 creates: $creates • ✏️ updates: $updates • 📝 writes: $writes • 🗑️ deletes: $deletes"
    fi
}