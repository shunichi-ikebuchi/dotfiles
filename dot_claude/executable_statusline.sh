#!/bin/bash
input=$(cat)

MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PARENT_DIR=$(dirname "$CURRENT_DIR")
PARENT_BASE=$(basename "$PARENT_DIR")
CURRENT_BASE=$(basename "$CURRENT_DIR")

GIT_BRANCH=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    GIT_BRANCH=" | 🌿 $BRANCH"
  fi
fi

echo "[$MODEL_DISPLAY] 📁 $PARENT_BASE/$CURRENT_BASE$GIT_BRANCH"
