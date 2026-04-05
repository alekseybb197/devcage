#!/usr/bin/env bash
# install.sh: Setup devcage environment and install qode command

set -e

# ============================================
# Part 1: Initialize devcage environment
# ============================================
echo "=== Initializing devcage environment ==="

DEVCAGE_DIR="$HOME/.devcage"
ROLES_DIR="$DEVCAGE_DIR/roles/default"
QWEN_SOURCE="$HOME/.qwen"
QWEN_TARGET="$ROLES_DIR/.qwen"

# Check if .qwen source exists
if [ ! -d "$QWEN_SOURCE" ]; then
  echo "Warning: ~/.qwen not found. Skipping .qwen copy."
else
  # Create devcage directory structure if it doesn't exist
  if [ ! -d "$ROLES_DIR" ]; then
    echo "Creating devcage directory structure..."
    mkdir -p "$ROLES_DIR"
    echo "Created: $ROLES_DIR"
  else
    echo "devcage directory already exists: $ROLES_DIR"
  fi

  # Copy .qwen to default role if not already present
  if [ ! -d "$QWEN_TARGET" ]; then
    echo "Copying ~/.qwen to devcage default role..."
    cp -r "$QWEN_SOURCE" "$QWEN_TARGET"
    echo "Successfully copied .qwen to $QWEN_TARGET"
  else
    echo "Default role .qwen already exists: $QWEN_TARGET"
  fi
fi

echo "=== Devcage environment initialization complete ==="
echo ""

# ============================================
# Part 2: Install qode command
# ============================================
echo "=== Installing qode command ==="

if [ -f "./run.sh" ]; then
  sudo cp "./run.sh" /usr/local/bin/qode
  sudo chmod +x /usr/local/bin/qode
  echo "Copied run.sh to /usr/local/bin/qode"
else
  echo "run.sh not found, skipping copy."
fi

echo "=== Installation complete ==="
