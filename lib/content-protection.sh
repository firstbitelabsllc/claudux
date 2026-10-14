#!/bin/bash

get_protection_markers() {
    local file="$1"
    local ext="${file##*.}"
    
    case "$ext" in
        md|markdown)
            printf '%s\n%s\n' "<!-- skip -->" "<!-- /skip -->"
            ;;
        swift|js|ts|jsx|tsx|java|c|cpp|h|hpp|rs|go)
            printf '%s\n%s\n' "// skip" "// /skip"
            ;;
        py|sh|bash|zsh|rb|pl)
            printf '%s\n%s\n' "# skip" "# /skip"
            ;;
        html|xml|vue)
            printf '%s\n%s\n' "<!-- skip -->" "<!-- /skip -->"
            ;;
        css|scss|sass|less)
            printf '%s\n%s\n' "/* skip */" "/* /skip */"
            ;;
        sql)
            printf '%s\n%s\n' "-- skip" "-- /skip"
            ;;
        *)
            printf '%s\n%s\n' "# skip" "# /skip"
            ;;
    esac
}
