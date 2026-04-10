#!/bin/bash
# entrypoint.sh — wrapper around qwen, logs the session via script

# ─── 1. Parse command line arguments ──────────────────────────
DEBUG_MODE=0
NEW_SESSION=0
ACP_MODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG_MODE=1
            shift
            ;;
        --new)
            NEW_SESSION=1
            shift
            ;;
        --acp)
            ACP_MODE=1
            shift
            ;;
        --*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            echo "Unexpected argument: $1" >&2
            exit 1
            ;;
    esac
done

DEVCAGE_PROJECT="${DEVCAGE_PROJECT:-}"
BASE_DIR="/workspace"
if [[ "x${DEVCAGE_PROJECT}" != "x" ]]; then
  cd "${BASE_DIR}/${DEVCAGE_PROJECT}"
  BASE_DIR="${BASE_DIR}/${DEVCAGE_PROJECT}"
fi

# ─── 2. Initialize DEVCAGE_ROLE, DEVCAGE_WORKFLOW, and DEVCAGE_NODE ──────────────
DEVCAGE_ROLE="${DEVCAGE_ROLE:-default}"
DEVCAGE_WORKFLOW="${DEVCAGE_WORKFLOW:-default}"
DEVCAGE_NODE="${DEVCAGE_NODE:-default}"
DEVCAGE_NODE_DIR="${BASE_DIR}/.devcage/${DEVCAGE_WORKFLOW}/${DEVCAGE_NODE}"

echo "🎭 Devcage role: ${DEVCAGE_ROLE}"
echo "🔗 Devcage node: ${DEVCAGE_NODE}"
echo "📋 Devcage workflow: ${DEVCAGE_WORKFLOW}"

QWEN_DIR="${BASE_DIR}/.qwen"
test -d "${QWEN_DIR}/skills"   || mkdir -p "${QWEN_DIR}/skills"
test -d "${QWEN_DIR}/sessions" || mkdir -p "${QWEN_DIR}/sessions"
SESSION_DIR="${QWEN_DIR}/sessions"

# Check and create .devcage node directory for session storage
test -d "${DEVCAGE_NODE_DIR}"       || mkdir -p "${DEVCAGE_NODE_DIR}"

# Determine build version from ~/devcage-release
if [[ -f "${HOME}/devcage-release" ]]; then
  BUILD_VERSION=$(grep '^BUILD_VERSION=' "${HOME}/devcage-release" | cut -d'=' -f2-)
else
  BUILD_VERSION="unknown"
fi
echo "🛠️ Build version: $BUILD_VERSION"

# Handle --new flag: remove old session.id to force new session
if [[ "${NEW_SESSION}" = "1" ]]; then
  echo "🔄 --new flag: creating new session"
  if [[ -f "${DEVCAGE_NODE_DIR}/session.id" ]]; then
    rm -f "${DEVCAGE_NODE_DIR}/session.id"
  fi
fi

# Save Qwen session ID if not already exists
if [[ ! -f "${DEVCAGE_NODE_DIR}/session.id" ]]; then
  echo "🔄 Creating new session ID..."
  SESSION_OUTPUT=$(qwen -p "show session id" --output-format json 2>&1)
  echo "📝 Qwen session output: ${SESSION_OUTPUT}"
  SESSION_ID=$(echo "${SESSION_OUTPUT}" | jq -r '.[0].session_id' 2>/dev/null)
  if [[ -n "${SESSION_ID}" && "${SESSION_ID}" != "null" ]]; then
    echo "${SESSION_ID}" > "${DEVCAGE_NODE_DIR}/session.id"
    echo "✅ Session ID created: ${SESSION_ID}"
  else
    echo "⚠️ Warning: Failed to create session ID, using placeholder" >&2
    echo "session-not-created" > "${DEVCAGE_NODE_DIR}/session.id"
  fi
else
  echo "ℹ️  Using existing session ID"
fi

# Read session ID for resume
SESSION_ID=$(cat "${DEVCAGE_NODE_DIR}/session.id" 2>/dev/null)

echo "📋 Session ID: ${SESSION_ID}"

# Debug/ACP mode: print environment and configuration, then wait
if [[ "${DEBUG_MODE}" = "1" ]]; then
  echo "🔧 Debug mode enabled"
  echo "   DEVCAGE_PROJECT: ${DEVCAGE_PROJECT}"
  echo "   BASE_DIR: ${BASE_DIR}"
  echo "   QWEN_DIR: ${QWEN_DIR}"
  echo "   DEVCAGE_ROLE: ${DEVCAGE_ROLE}"
  echo "   DEVCAGE_WORKFLOW: ${DEVCAGE_WORKFLOW}"
  echo "   DEVCAGE_NODE: ${DEVCAGE_NODE}"
  echo "   DEVCAGE_NODE_DIR: ${DEVCAGE_NODE_DIR}"
  echo "   NEW_SESSION: ${NEW_SESSION}"
  echo ""
  echo "🔹 Container is ready for debugging. Connect from outside and run 'qwen' manually."
  echo "   Example: docker exec -it ${HOSTNAME} bash"
  echo ""
  echo "⏳ Waiting indefinitely..."
  exec tail -f /dev/null

elif [[ "${ACP_MODE}" = "1" ]]; then
  echo "🤖 ACP mode enabled"
  echo "   DEVCAGE_PROJECT: ${DEVCAGE_PROJECT}"
  echo "   DEVCAGE_ROLE: ${DEVCAGE_ROLE}"
  echo "   DEVCAGE_WORKFLOW: ${DEVCAGE_WORKFLOW}"
  echo "   DEVCAGE_NODE: ${DEVCAGE_NODE}"
  echo ""
  echo "🔹 Container is ready for ACP. Connect from outside and interact."
  echo "   Example: docker exec -it ${HOSTNAME} bash"
  echo ""
  echo "⏳ Waiting indefinitely..."
  exec tail -f /dev/null

else

  # Normal mode: run qwen with session resume
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

fi