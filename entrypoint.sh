#!/bin/bash
# entrypoint.sh — wrapper around qwen, logs the session via script

PROJECT_DIR=$1

BASE_DIR="/workspace"
if [[ "x${PROJECT_DIR}" != "x" ]]; then
  cd ${PROJECT_DIR}
  BASE_DIR="${BASE_DIR}/${PROJECT_DIR}"
fi

QWEN_DIR="${BASE_DIR}/.qwen"
test -d "${QWEN_DIR}/skills"   || mkdir -p "${QWEN_DIR}/skills"
test -d "${QWEN_DIR}/sessions" || mkdir -p "${QWEN_DIR}/sessions"
SESSION_DIR="${QWEN_DIR}/sessions"

# Determine build version from ~/devcage-release
if [[ -f "${HOME}/devcage-release" ]]; then
  BUILD_VERSION=$(grep '^BUILD_VERSION=' "${HOME}/devcage-release" | cut -d'=' -f2-)
else
  BUILD_VERSION="unknown"
fi
echo "🛠️ Build version: $BUILD_VERSION"

# Save Qwen session ID if not already exists
if [[ ! -f "${QWEN_DIR}/session.id" ]]; then
  qwen -p "show session id" --output-format json | jq -r '.[0].session_id' > "${QWEN_DIR}/session.id"
fi

# Read session ID for resume
SESSION_ID=$(cat "${QWEN_DIR}/session.id" 2>/dev/null)

# Run qwen with session resume
qwen --resume "${SESSION_ID}"

# Copy session log from ~/.qwen/projects/{project-folder}/{SESSION_ID}.jsonl to SESSION_DIR
PROJECT_FOLDER=$(echo "${BASE_DIR}" | tr '/' '-')
SESSION_LOG="${HOME}/.qwen/projects/${PROJECT_FOLDER}/chats/${SESSION_ID}.jsonl"
SESSION_LOG_DEST="${SESSION_DIR}/$(date +%Y%m%d-%H%M%S)-${SESSION_ID}.jsonl"

if [[ -f "${SESSION_LOG}" ]]; then
  cp "${SESSION_LOG}" "${SESSION_LOG_DEST}"
  echo "Copied session log: ${SESSION_LOG} -> ${SESSION_LOG_DEST}"
else
  echo "Warning: session log not found at ${SESSION_LOG}" >&2
fi
