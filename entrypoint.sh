#!/bin/bash
# entrypoint.sh — wrapper around qwen, logs the session via script

PROJECT_DIR=$1

BASE_DIR="/workspace"
if [[ "x${PROJECT_DIR}" != "x" ]]; then
  cd ${PROJECT_DIR}
  BASE_DIR="${BASE_DIR}/${PROJECT_DIR}"
fi

LOG_DIR="${BASE_DIR}/.qwen/sessions"
mkdir -p "${LOG_DIR}"

QWEN_DIR="${BASE_DIR}/.qwen"
test -d "${QWEN_DIR}/skills"   || mkdir -p "${QWEN_DIR}/skills"
test -d "${QWEN_DIR}/sessions" || mkdir -p "${QWEN_DIR}/sessions"

# Determine build version from ~/devcage-release
if [[ -f "${HOME}/devcage-release" ]]; then
  BUILD_VERSION=$(grep '^BUILD_VERSION=' "${HOME}/devcage-release" | cut -d'=' -f2-)
else
  BUILD_VERSION="unknown"
fi
echo "🛠️ Build version: $BUILD_VERSION"
SESSION_CAST="${LOG_DIR}/session-$(date +%Y%m%d-%H%M%S).cast"
echo "📝 Recording session: ${SESSION_CAST}"
# .cast file format (JSON-based, no noise)

# --stdin: record user input
# --command: command to execute
# Logs are immediately visible on the host if the directory is mounted via -v
asciinema rec --stdin "${SESSION_CAST}" -c "qwen"
# After the session finishes, copy the session log
# After the session finishes, copy the session log
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${HOME}/.qwen/tmp"

# Find the most recent logs.json in ~/.qwen/tmp/
LATEST_TMP_DIR=$(ls -t "${TMP_DIR}"/*/logs.json 2>/dev/null | head -1 | xargs -I{} dirname {})
if [[ -z "${LATEST_TMP_DIR}" ]]; then
  echo "Error: no directories found in ${TMP_DIR}" >&2
  exit 1
fi
LOGS_FILE="${LATEST_TMP_DIR}/logs.json"
if [[ ! -f "${LOGS_FILE}" ]]; then
  echo "Error: logs.json not found in ${LATEST_TMP_DIR}" >&2
  exit 1
fi

# Find the newest .cast session file
LATEST_SESSION=$(ls -t "${LOG_DIR}"/*.cast 2>/dev/null | head -1)
if [[ -z "${LATEST_SESSION}" ]]; then
  echo "Error: no session files found in ${LOG_DIR}" >&2
  exit 1
fi

OUTPUT_FILE="${LATEST_SESSION%.cast}.host.json"
cp "${LOGS_FILE}" "${OUTPUT_FILE}"
echo "Copied: ${LOGS_FILE} -> ${OUTPUT_FILE}"
# Plain‑text conversion disabled (cast file kept)
# Convert .cast to .json using cast-extractor
cast-extractor.py "${SESSION_CAST}" -o "${SESSION_CAST%.cast}.cast.json"
