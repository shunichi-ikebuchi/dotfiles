# wcc: Ephemeral worktree management with tmux integration
# Powered by wcc-core for ephemeral worktree creation

# Main command: Create ephemeral worktree
wcc() {
    local cleanup=false
    local auto_cleanup=false

    # Parse options
    while [ $# -gt 0 ]; do
        case "$1" in
            --cleanup|-c)
                cleanup=true
                shift
                ;;
            --auto-cleanup|-a)
                auto_cleanup=true
                shift
                ;;
            --help|-h)
                echo "Usage: wcc [options]"
                echo ""
                echo "Create ephemeral worktree for quick experiments"
                echo ""
                echo "Options:"
                echo "  -c, --cleanup       Setup cleanup on tmux session close"
                echo "  -a, --auto-cleanup  Auto-delete worktree on shell exit"
                echo "  -h, --help          Show this help"
                echo ""
                echo "Examples:"
                echo "  wcc              # Basic usage"
                echo "  wcc -c           # With cleanup (recommended for tmux)"
                echo "  wcc -a           # Auto-delete on shell exit"
                echo ""
                echo "Workflow:"
                echo "  1. wcc -c                          # Start experiment"
                echo "  2. (work...)                       # Make changes"
                echo "  3. wcc-commit feat/163-feature     # Promote to named branch"
                echo "  4. git push / PR / merge           # Normal git workflow"
                echo "  5. gwq remove feat/163-feature     # Cleanup after merge"
                echo ""
                echo "Additional commands:"
                echo "  wcc-commit <branch>       Promote ephemeral worktree to named branch"
                echo "  wcc-exclude <command>     Manage git/info/exclude patterns"
                echo "  wcc-copy <target> [files] Copy files to another worktree"
                return 0
                ;;
            *)
                break
                ;;
        esac
    done

    # Create ephemeral worktree via wcc-core
    local dest
    dest="$(wcc-core "$@")" || return
    [ -n "$dest" ] || return

    local branch=$(basename "$dest")

    builtin cd "$dest" || return

    printf "[wcc] 📁 %s\n" "$PWD"
    printf "[wcc] 🌿 %s\n" "$branch"

    # tmux integration
    if [ -n "$TMUX" ]; then
        local session="wcc-${branch}"

        if ! tmux has-session -t "$session" 2>/dev/null; then
            tmux new-session -d -s "$session" -c "$PWD"

            # Setup cleanup hook for tmux session
            if [ "$cleanup" = true ] || [ "$auto_cleanup" = true ]; then
                tmux set-hook -t "$session" session-closed \
                    "run-shell 'git worktree remove \"$dest\" --force 2>/dev/null || true'"
                printf "[wcc] 🗑️  Auto-cleanup: tmux close → worktree delete\n"
            fi

            printf "[wcc] ✨ Session: %s\n" "$session"
        fi

        tmux switch-client -t "$session"
    else
        # Non-tmux: shell exit cleanup
        if [ "$auto_cleanup" = true ]; then
            trap "echo '[wcc] Cleaning up: $dest' && git worktree remove '$dest' --force 2>/dev/null" EXIT
            printf "[wcc] 🗑️  Auto-cleanup: shell exit → worktree delete\n"
        fi
    fi

    printf "[wcc] 💡 Tip: wcc-commit <branch-name> to promote this worktree\n"
}

# wcc-commit: Promote ephemeral worktree to named branch (same worktree)
wcc-commit() {
    local new_branch="$1"

    if [ -z "$new_branch" ]; then
        echo "Usage: wcc-commit <branch-name>"
        echo ""
        echo "Promote ephemeral worktree to named branch (same worktree)"
        echo ""
        echo "Examples:"
        echo "  wcc-commit feat/163-payment-retry"
        echo "  wcc-commit fix/auth-bug"
        echo ""
        echo "After promotion:"
        echo "  - Continue working in same directory"
        echo "  - Use normal git workflow (commit, push, PR)"
        echo "  - Delete worktree after merge: gwq remove <branch>"
        return 1
    fi

    # Check if in worktree
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$current_branch" ]; then
        echo "[wcc] Error: Not in a git repository"
        return 1
    fi

    echo "[wcc] 🔄 Promoting: $current_branch → $new_branch"

    # Check if new branch already exists
    if git show-ref --verify --quiet "refs/heads/$new_branch"; then
        echo "[wcc] ❌ Branch '$new_branch' already exists"
        echo "[wcc] Delete it first: git branch -D $new_branch"
        return 1
    fi

    # Create new branch from current HEAD
    git branch "$new_branch" || {
        echo "[wcc] Error: Failed to create branch"
        return 1
    }

    # Switch to new branch
    git checkout "$new_branch" || {
        echo "[wcc] Error: Failed to checkout"
        git branch -d "$new_branch"
        return 1
    }

    echo "[wcc] ✅ Branch: $new_branch"
    echo "[wcc] 📁 Worktree: $PWD"

    # Update tmux session name if in tmux
    if [ -n "$TMUX" ]; then
        local old_session="wcc-${current_branch}"
        local new_session="aigis-${new_branch}"

        if tmux has-session -t "$old_session" 2>/dev/null; then
            echo "[wcc] 📺 Renaming session: $old_session → $new_session"
            tmux rename-session -t "$old_session" "$new_session"

            # Disable auto-cleanup hook (now it's a named branch)
            tmux set-hook -t "$new_session" -u session-closed
            echo "[wcc] 🔓 Auto-cleanup disabled (use 'gwq remove' after merge)"
        fi
    fi

    echo ""
    echo "[wcc] 📋 Next steps:"
    echo "  1. git add . && git commit -m 'feat: ...'"
    echo "  2. git push -u origin $new_branch"
    echo "  3. gh pr create"
    echo "  4. After merge: gwq remove $new_branch"
}

# wcc-exclude: Manage git/info/exclude (worktree-specific ignore)
wcc-exclude() {
    local action="$1"
    shift

    local git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ -z "$git_common_dir" ]; then
        echo "[wcc] Error: Not in a git repository"
        return 1
    fi

    local exclude_file="$git_common_dir/info/exclude"

    case "$action" in
        add|a)
            if [ $# -eq 0 ]; then
                echo "Usage: wcc-exclude add <pattern> [pattern...]"
                echo ""
                echo "Add patterns to git/info/exclude (worktree-local ignore)"
                echo ""
                echo "Examples:"
                echo "  wcc-exclude add '*.tmp' '*.log'"
                echo "  wcc-exclude add 'node_modules/'"
                return 1
            fi

            echo "[wcc] Adding to $exclude_file:"
            for pattern in "$@"; do
                # Check if pattern already exists
                if grep -qFx "$pattern" "$exclude_file" 2>/dev/null; then
                    echo "  - $pattern (already exists)"
                else
                    echo "$pattern" >> "$exclude_file"
                    echo "  + $pattern"
                fi
            done
            ;;

        list|l)
            echo "[wcc] Current exclude patterns ($exclude_file):"
            if [ -f "$exclude_file" ]; then
                cat "$exclude_file" | grep -v '^#' | grep -v '^$' | sed 's/^/  /'
            else
                echo "  (empty)"
            fi
            ;;

        edit|e)
            "${EDITOR:-vim}" "$exclude_file"
            ;;

        *)
            echo "Usage: wcc-exclude <command> [args]"
            echo ""
            echo "Commands:"
            echo "  add <pattern>   Add pattern to exclude"
            echo "  list            List current patterns"
            echo "  edit            Edit exclude file"
            echo ""
            echo "Examples:"
            echo "  wcc-exclude add '*.tmp'"
            echo "  wcc-exclude list"
            echo "  wcc-exclude edit"
            return 1
            ;;
    esac
}

# wcc-copy: Copy files from current worktree to another
wcc-copy() {
    local target="$1"
    shift

    if [ -z "$target" ]; then
        echo "Usage: wcc-copy <target-worktree> [files...]"
        echo ""
        echo "Copy files from current worktree to target worktree"
        echo ""
        echo "Examples:"
        echo "  wcc-copy feat/163-payment-retry              # Copy all uncommitted changes"
        echo "  wcc-copy feat/163-payment-retry file1.go     # Copy specific files"
        echo "  wcc-copy main api/internal/modules/          # Copy directory"
        return 1
    fi

    # Get target worktree path
    local target_path
    target_path=$(gwq get "$target" 2>/dev/null)

    if [ -z "$target_path" ]; then
        echo "[wcc] Error: Target worktree not found: $target"
        echo "[wcc] Available worktrees:"
        gwq list
        return 1
    fi

    target_path="${target_path/#\~/$HOME}"

    if [ ! -d "$target_path" ]; then
        echo "[wcc] Error: Target directory not found: $target_path"
        return 1
    fi

    echo "[wcc] Copying to: $target_path"

    if [ $# -eq 0 ]; then
        # Copy all uncommitted changes
        echo "[wcc] Copying all uncommitted changes..."

        # Get list of modified/new files
        local files
        files=$(git status --porcelain | awk '{print $2}')

        if [ -z "$files" ]; then
            echo "[wcc] No uncommitted changes to copy"
            return 0
        fi

        echo "$files" | while IFS= read -r file; do
            if [ -f "$file" ]; then
                local target_file="$target_path/$file"
                mkdir -p "$(dirname "$target_file")"
                cp -v "$file" "$target_file"
            fi
        done
    else
        # Copy specific files/directories
        for item in "$@"; do
            if [ -e "$item" ]; then
                local target_item="$target_path/$item"
                mkdir -p "$(dirname "$target_item")"

                if [ -d "$item" ]; then
                    cp -rv "$item" "$(dirname "$target_item")/"
                else
                    cp -v "$item" "$target_item"
                fi
            else
                echo "[wcc] Warning: Not found: $item"
            fi
        done
    fi

    echo "[wcc] ✅ Copy complete"
}
