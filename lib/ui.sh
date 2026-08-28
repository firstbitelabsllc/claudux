#!/bin/bash
# User interface and menu functions

# Show the main header
show_header() {
    load_project_config
    local backend="${CLAUDUX_BACKEND:-claude}"
    local powered_by="Claude AI"
    if [[ "$backend" == "codex" ]]; then
        local codex_model="${CODEX_MODEL:-gpt-5.4}"
        local codex_effort="${CODEX_REASONING_EFFORT:-xhigh}"
        powered_by="Codex (${codex_model}, ${codex_effort} reasoning)"
    fi
    echo "📚 claudux - ${PROJECT_NAME} Documentation"
    echo "Generate docs from your codebase · powered by $powered_by"
    echo ""
}

# Show help and usage information
show_help() {
    echo ""
    echo "claudux - Generate docs from your codebase"
    echo "Generate VitePress docs from your codebase, preview them locally, ship them."
    echo ""
    echo "💡 Quick Tips:"
    echo "• Commit a docs-structure.json to hash-guard pinned and skip-marker blocks"
    echo "• Generation prompts steer the model away from notes/ and private/"
    echo "• Local shell orchestration; backend CLIs handle model transport"
    echo "• Press Ctrl+C anytime to cancel"
    echo ""
    echo "Commands:"
    echo "  claudux                  - Show interactive menu"
    echo "  claudux update           - Generate/update docs, enforce boundaries, validate links"
    echo "  claudux update -m \"msg\"  - Update with a focused directive for Claude"
    echo "  claudux serve            - Start docs server (localhost:5173)"
    echo "  claudux check            - Verify environment (Node, Claude CLI, docs)"
    echo "  claudux help             - Show this help"
    echo "  claudux --version        - Show installed version"
    echo ""
    echo "Options:"
    echo "  --with, -m               - Provide a high-level directive to guide generation"
    echo "  --strict                 - Fail on broken internal links (update command)"
    echo ""
    echo "Environment:"
    echo "  FORCE_MODEL=fable|opus|sonnet - Select Claude model (default: claudux.json project.model, else sonnet)"
    echo "  CLAUDUX_BACKEND=codex    - Use Codex instead of Claude"
    echo "  CODEX_MODEL=...          - Select Codex model (default: gpt-5.4)"
    echo "  CODEX_REASONING_EFFORT=... - Select Codex reasoning effort (default: xhigh)"
    echo "  CLAUDUX_MESSAGE=...      - Default directive if -m/--with not provided"
    echo ""
    echo "💡 The main update command automatically:"
    echo "  • Scans your codebase and updates docs"
    echo "  • Rolls back non-doc mutations; manifest mode applies section patches"
    echo "  • Validates links to prevent 404s"
    echo ""
    echo "🛡️ Content protection:"
    echo "  • With docs-structure.json: model is read-only; docs writes are"
    echo "    transactionally section-bounded and hash-guarded"
    echo "  • Without it: docs paths are writable, but unrelated Git paths and"
    echo "    commits are detected, rejected, and restored"
    echo ""
}

# Interactive menu system
show_menu() {
    # Check if docs exist to determine menu type
    local has_docs=false
    if [[ -d "docs" ]] && [[ -f "docs/index.md" ]] && [[ $(ls -A docs/*.md 2>/dev/null | wc -l) -gt 1 ]]; then
        has_docs=true
    fi

    if [[ "$has_docs" == "false" ]]; then
        # First run menu - no docs yet
        echo "Select:"
        echo ""

        PS3="> "

        select choice in \
            "Generate docs              (scan code → markdown)" \
            "Serve                      (vitepress dev server)" \
            "Exit"
        do
            case $choice in
                "Generate docs              (scan code → markdown)")
                    echo ""
                    update
                    break
                    ;;
                "Serve                      (vitepress dev server)")
                    echo ""
                    serve
                    break
                    ;;
                "Exit")
                    echo ""
                    exit 0
                    ;;
                *)
                    print_color "RED" "Invalid"
                    ;;
            esac
        done
    else
        # Existing project menu - docs present
        echo "Select:"
        echo ""

        PS3="> "

        select choice in \
            "Update docs                (regenerate from code)" \
            "Update (focused)           (enter directive → update)" \
            "Serve                      (vitepress dev server)" \
            "Exit"
        do
            case $choice in
                "Update docs                (regenerate from code)")
                    echo ""
                    update
                    break
                    ;;
                "Update (focused)           (enter directive → update)")
                    echo ""
                    read -r -p "Enter focused directive (leave empty to cancel): " directive
                    if [[ -n "$directive" ]]; then
                        update --with "$directive"
                    else
                        warn "No directive entered; cancelled."
                    fi
                    break
                    ;;
                "Serve                      (vitepress dev server)")
                    echo ""
                    serve
                    break
                    ;;
                "Exit")
                    echo ""
                    exit 0
                    ;;
                *)
                    print_color "RED" "Invalid"
                    ;;
            esac
        done
    fi

    # Footer hint
    echo ""
    echo "Run 'claudux --help' for help."
}
