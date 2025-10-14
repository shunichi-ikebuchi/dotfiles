#!/bin/bash
input=$(cat)

MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path')
PARENT_DIR=$(dirname "$CURRENT_DIR")
PARENT_BASE=$(basename "$PARENT_DIR")
CURRENT_BASE=$(basename "$CURRENT_DIR")

# Calculate context usage
CONTEXT_USAGE=""
if [ -f "$TRANSCRIPT_PATH" ]; then
  # Get the latest message's token usage (which represents current context size)
  TOTAL_TOKENS=$(tail -1 "$TRANSCRIPT_PATH" | jq '.message.usage |
    if . != null then
      (.input_tokens // 0) +
      (.cache_creation_input_tokens // 0) +
      (.cache_read_input_tokens // 0)
    else 0 end')

  # Calculate percentage (out of 200K)
  if [ "$TOTAL_TOKENS" != "null" ] && [ "$TOTAL_TOKENS" -gt 0 ]; then
    PERCENTAGE=$(awk -v tokens="$TOTAL_TOKENS" 'BEGIN {printf "%.0f", (tokens / 200000) * 100}')
    CONTEXT_USAGE=" | 📊 ${PERCENTAGE}%"
  fi
fi

GIT_BRANCH=""
if [ -d "$CURRENT_DIR" ]; then
  cd "$CURRENT_DIR" 2>/dev/null
  if git rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
      GIT_BRANCH=" | 🌿 $BRANCH"
    fi
  fi
fi

echo "🧠 $MODEL_DISPLAY | 📁 $PARENT_BASE/$CURRENT_BASE$GIT_BRANCH$CONTEXT_USAGE"
