#!/bin/bash
# Git utilities for change tracking and analysis

_git_status_has_second_path() {
    case "$1" in
        *R*|*C*) return 0 ;;
    esac
    return 1
}

_format_git_path() {
    local path="$1"

    path=${path//\\/\\\\}
    path=${path//\"/\\\"}
    path=${path//$'\t'/\\t}
    path=${path//$'\n'/\\n}
    path=${path//$'\r'/\\r}

    printf '"%s"' "$path"
}

_git_status_path_is_ignored() {
    case "$1" in
        *node_modules/*|\
        *package-lock.json*|\
        *package.json*|\
        *.vitepress/cache/*|\
        *.vitepress/dist/*|\
        *.vitepress/temp/*)
            return 0
            ;;
    esac
    return 1
}

# Show current git status summary
show_git_status() {
    info "📋 Current repository status:"

    local record status path original_path
    local formatted_path formatted_original_path
    local status_count=0
    local shown_count=0

    while IFS= read -r -d '' record; do
        status="${record:0:2}"
        path="${record:3}"
        original_path=""

        if _git_status_has_second_path "$status"; then
            IFS= read -r -d '' original_path || original_path=""
        fi

        status_count=$((status_count + 1))

        if [[ $shown_count -lt 10 ]]; then
            formatted_path=$(_format_git_path "$path")
            if [[ -n "$original_path" ]]; then
                formatted_original_path=$(_format_git_path "$original_path")
                printf '%s %s -> %s\n' "$status" "$formatted_original_path" "$formatted_path"
            else
                printf '%s %s\n' "$status" "$formatted_path"
            fi
            shown_count=$((shown_count + 1))
        fi
    done < <(git status --porcelain=v1 -z 2>/dev/null)

    if [[ $status_count -eq 0 ]]; then
        echo "   Working directory clean"
        return
    fi

    if [[ $status_count -gt 10 ]]; then
        echo "   ... and $((status_count - 10)) more files"
    fi
}

# Show detailed changes with semantic descriptions
show_detailed_changes() {
    local statuses=()
    local paths=()
    local original_paths=()
    local record status path original_path index
    local changed_count

    while IFS= read -r -d '' record; do
        status="${record:0:2}"
        path="${record:3}"
        original_path=""

        if _git_status_has_second_path "$status"; then
            IFS= read -r -d '' original_path || original_path=""
        fi

        if _git_status_path_is_ignored "$path"; then
            continue
        fi
        if [[ -n "$original_path" ]] && _git_status_path_is_ignored "$original_path"; then
            continue
        fi

        index=${#statuses[@]}
        statuses[$index]="$status"
        paths[$index]="$path"
        original_paths[$index]="$original_path"
    done < <(git status --porcelain=v1 -z -- docs/ 2>/dev/null)

    changed_count=${#statuses[@]}
    if [[ $changed_count -eq 0 ]]; then
        info "   📝 No documentation files were modified"
        echo ""
        warn "💡 Next steps:"
        warn "   • Documentation appears to be up-to-date"
        warn "   • Try making code changes and running again"
        return
    fi
    
    echo ""
    success "📄 Files changed:"
    echo ""

    local file formatted_original_path
    for ((index = 0; index < changed_count; index++)); do
        status="${statuses[$index]}"
        file=$(_format_git_path "${paths[$index]}")
        original_path="${original_paths[$index]}"

        if [[ -n "$original_path" ]]; then
            formatted_original_path=$(_format_git_path "$original_path")
            file="$formatted_original_path -> $file"
        fi

        case "$status" in
            "A ")
                success "   ✅ Created: $file - New documentation file"
                ;;
            "M ")
                info "   📝 Updated: $file - Content synchronized with codebase"
                ;;
            "D ")
                print_color "RED" "   🗑️  Deleted: $file - Obsolete or duplicate content removed"
                ;;
            "R ")
                warn "   📦 Renamed: $file - File reorganized"
                ;;
            "??")
                success "   ✨ Added: $file - New documentation generated"
                ;;
            *)
                info "   📋 Modified: $file - Documentation updated"
                ;;
        esac
    done

    echo ""
    warn "💡 Next steps:"
    warn "   • Review changes: git diff docs/"
    warn "   • Commit changes: git add docs/ && git commit -m '📚 Update documentation'"
    warn "   • Shelve safely if needed: git stash push -m 'claudux docs review' -- docs/"
}

# Check if we're in a git repository
ensure_git_repo() {
    if ! git rev-parse --git-dir &> /dev/null; then
        warn "Not in a git repository. Git features will be limited."
        return 1
    fi
    return 0
}
