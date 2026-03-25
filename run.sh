#!/bin/bash
# run.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ─── 1. Settings ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${1:-$(pwd)}"
PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)"
PROJECT_NAME="$(basename "${PROJECT_PATH}")"
SESSION_NAME="qwen-${PROJECT_NAME}"
CONTAINER_NAME="qwen-${PROJECT_NAME}-$(date +%s)"
DEBUG_MODE="${QWEN_DEBUG_RUN:-0}"

# ─── 2. Path Check ──────────────────────────────────────────
if [ ! -d "${PROJECT_PATH}" ]; then
    echo -e "${RED}❌ Path does not exist: ${PROJECT_PATH}${NC}"
    exit 1
fi

# ─── 3. Image Tag Determination ─────────────────────────────────
# If QODE_VERSION is set, use it as the image tag; otherwise, find the latest image
if [ -n "${QODE_VERSION}" ]; then
    IMAGE_TAG="${QODE_VERSION}"
    echo -e "${GREEN}✅ Using qwen-code image with specified tag:${BLUE} $IMAGE_TAG${NC}"
else
    IMAGE_TAG=$(docker images --filter=reference='qwen-code:*' --format '{{.Tag}} {{.CreatedAt}}' | sort -r -k2 | head -n1 | awk '{print $1}')
    if [ -z "$IMAGE_TAG" ]; then
        echo -e "${RED}❌ No qwen-code image found with any tag!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Selected qwen-code image:${BLUE} $IMAGE_TAG${NC}"
fi

# ─── 4. Prepare session log directory ───────────────────────────
SESSION_LOG_DIR="${PROJECT_PATH}/.qwen/sessions"
mkdir -p "${SESSION_LOG_DIR}"
chmod 777 "${SESSION_LOG_DIR}" 2>/dev/null || true

echo -e "${GREEN}📝 Session log: ${BLUE}${SESSION_LOG_DIR}/session.log${NC}"
echo ""

# ─── 5. tmux ───────────────────────────────────────────────────
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}❌ tmux not found!${NC}"
    echo -e "   Install: ${BLUE}brew install tmux${NC} (macOS) or ${BLUE}sudo apt install tmux${NC} (Linux)"
    exit 1
fi

echo -e "${GREEN}🔹 Starting in tmux session: ${SESSION_NAME}${NC}"

if tmux has-session -t "${SESSION_NAME}" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Session already exists.${NC}"
    echo -e "   Attach: ${BLUE}tmux attach -t ${SESSION_NAME}${NC}"
    echo -e "   Kill old: ${BLUE}tmux kill-session -t ${SESSION_NAME}${NC}"
    echo ""
    read -p "Attach to existing session? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tmux attach -t "${SESSION_NAME}"
        exit 0
    else
        tmux kill-session -t "${SESSION_NAME}"
    fi
fi

# ─── 6. Build docker run command into a temporary script and execute ─────────
#
# FIX for macOS: mktemp can be flaky, so we create the file explicitly
#
TMP_SCRIPT="/tmp/qwen-run-${$}-${RANDOM}.sh"

# Check that /tmp is available
if [ ! -d "/tmp" ] || [ ! -w "/tmp" ]; then
    echo -e "${RED}❌ /tmp is not writable${NC}"
    exit 1
fi

# Create the file explicitly (more reliable than mktemp on macOS)
touch "${TMP_SCRIPT}" || {
    echo -e "${RED}❌ Failed to create temporary file: ${TMP_SCRIPT}${NC}"
    echo -e "   Try: ${BLUE}sudo chmod 1777 /tmp${NC}"
    exit 1
}

chmod +x "${TMP_SCRIPT}" || {
    echo -e "${RED}❌ Failed to make file executable${NC}"
    rm -f "${TMP_SCRIPT}"
    exit 1
}

RM_FLAG="--rm"
[ "${DEBUG_MODE}" = "1" ] && RM_FLAG=""

cat > "${TMP_SCRIPT}" <<DOCKER_CMD
#!/bin/bash
set -e
# Ensure the session log directory exists and is writable
mkdir -p "${SESSION_LOG_DIR}"
chmod 777 "${SESSION_LOG_DIR}" 2>/dev/null || true
docker run -it ${RM_FLAG} \
    --name "${CONTAINER_NAME}" \
    -v "${PROJECT_PATH}:/workspace/${PROJECT_NAME}" \
    -v "${HOME}/.qwen:/home/agent/.qwen:ro" \
    -v "${HOME}/.qwen/agents:/home/agent/.qwen/agents" \
    -v "${HOME}/.qwen/debug:/home/agent/.qwen/debug" \
    -v "${HOME}/.qwen/insight:/home/agent/.qwen/insight" \
    -v "${HOME}/.qwen/projects:/home/agent/.qwen/projects" \
    -v "${HOME}/.qwen/skills:/home/agent/.qwen/skills" \
    -v "${HOME}/.qwen/tmp:/home/agent/.qwen/tmp" \
    -v "${HOME}/.qwen/todos:/home/agent/.qwen/todos" \
    -v "${HOME}/.ssh:/home/agent/.ssh:ro" \
    -v "${HOME}/.kube:/home/agent/.kube:ro" \
    -v "/etc/hosts:/etc/hosts:ro" \
    -e QWEN_MODEL="${QWEN_MODEL:-qwen-max}" \
    -e QWEN_DEBUG=1 \
    -w /workspace \
    --user agent \
    --entrypoint /usr/local/bin/entrypoint.sh \
    qwen-code:${IMAGE_TAG} ${PROJECT_NAME}
# Remove the temporary script after execution
rm -f "${TMP_SCRIPT}"
DOCKER_CMD

# Verify that the file was written
if [ ! -s "${TMP_SCRIPT}" ]; then
    echo -e "${RED}❌ Temporary file is empty${NC}"
    rm -f "${TMP_SCRIPT}"
    exit 1
fi

# ─── 7. Launch in tmux ──────────────────────────────────────────
tmux new-session -d -s "${SESSION_NAME}" "${TMP_SCRIPT}"

echo -e "${GREEN}✅ Container started in tmux.${NC}"
echo -e ""
echo -e "   ${BLUE}Controls:${NC}"
echo -e "   • Detach:  ${BLUE}Ctrl+B, then D${NC}"
echo -e "   • Reattach:    ${BLUE}tmux attach -t ${SESSION_NAME}${NC}"
echo -e "   • Kill session: ${BLUE}tmux kill-session -t ${SESSION_NAME}${NC}"
echo -e ""
echo -e "   ${BLUE}Qwen logs:${NC} ~/.qwen/debug/"
echo -e ""

if [ "${DEBUG_MODE}" = "1" ]; then
    echo -e "   ${YELLOW}🔧 Debug mode is active.${NC}"
    echo -e "   If the container crashes:"
    echo -e "   ${BLUE}docker logs ${CONTAINER_NAME}${NC}"
    echo -e "   ${BLUE}docker inspect ${CONTAINER_NAME}${NC}"
    echo -e "   ${BLUE}docker rm ${CONTAINER_NAME}${NC}"
    echo -e ""
fi

tmux attach -t "${SESSION_NAME}"
