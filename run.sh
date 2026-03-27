#!/bin/bash
# run.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ─── 1. Parse command line arguments ──────────────────────────
DEBUG_MODE=0
NEW_SESSION=0
PROJECT_PATH=""

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
        --help|-h)
            echo "Usage: $(basename "$0") [OPTIONS] [PROJECT_PATH]"
            echo ""
            echo "Start Qwen Code in a Docker container."
            echo ""
            echo "Options:"
            echo "  --debug      Pass --debug flag to entrypoint (debug mode in container)"
            echo "  --new        Pass --new flag to entrypoint (new Qwen session)"
            echo "  -h, --help   Show this help message"
            echo ""
            echo "Arguments:"
            echo "  PROJECT_PATH  Path to project directory (default: current directory)"
            echo ""
            echo "Examples:"
            echo "  $(basename "$0")"
            echo "  $(basename "$0") /path/to/project"
            echo "  $(basename "$0") --debug --new /path/to/project"
            echo "  $(basename "$0") --new /path/to/project --debug"
            exit 0
            ;;
        --*)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo -e "   Use ${BLUE}--help${NC} to see available options"
            exit 1
            ;;
        *)
            if [ -z "${PROJECT_PATH}" ]; then
                PROJECT_PATH="$1"
            else
                echo -e "${RED}❌ Unexpected argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Default to current directory if no path specified
if [ -z "${PROJECT_PATH}" ]; then
    PROJECT_PATH="$(pwd)"
fi

# ─── 2. Settings ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$(cd "${PROJECT_PATH}" && pwd)"
PROJECT_NAME="$(basename "${PROJECT_PATH}")"
SESSION_NAME="qwen-${PROJECT_NAME}"
CONTAINER_NAME="qwen-${PROJECT_NAME}-$(date +%s)"

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

# ─── 4.1. Check and create required ~/.qwen directories ─────────
QWEN_DIRS=(
    "${HOME}/.qwen"
    "${HOME}/.qwen/agents"
    "${HOME}/.qwen/debug"
    "${HOME}/.qwen/insights"
    "${HOME}/.qwen/projects"
    "${HOME}/.qwen/skills"
    "${HOME}/.qwen/tmp"
    "${HOME}/.qwen/todos"
)

echo -e "${GREEN}🔍 Checking ~/.qwen directories...${NC}"
for dir in "${QWEN_DIRS[@]}"; do
    if [ ! -d "${dir}" ]; then
        echo -e "${YELLOW}⚠️  Creating missing directory: ${BLUE}${dir}${NC}"
        mkdir -p "${dir}"
    fi
done
echo -e "${GREEN}✅ All required directories are ready.${NC}"
echo ""

# ─── 5. tmux check (only if not in debug mode) ─────────────────
if [ "${DEBUG_MODE}" = "0" ]; then
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
[ "${DEBUG_QODE}" = "1" ] && RM_FLAG=""

# Build entrypoint arguments
ENTRYPOINT_ARGS=""
[ "${DEBUG_MODE}" = "1" ] && ENTRYPOINT_ARGS="${ENTRYPOINT_ARGS} --debug"
[ "${NEW_SESSION}" = "1" ] && ENTRYPOINT_ARGS="${ENTRYPOINT_ARGS} --new"

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
    -v "${HOME}/.qwen/insights:/home/agent/.qwen/insights" \
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
    qwen-code:${IMAGE_TAG} ${PROJECT_NAME}${ENTRYPOINT_ARGS}
# Remove the temporary script after execution
rm -f "${TMP_SCRIPT}"
DOCKER_CMD

# Verify that the file was written
if [ ! -s "${TMP_SCRIPT}" ]; then
    echo -e "${RED}❌ Temporary file is empty${NC}"
    rm -f "${TMP_SCRIPT}"
    exit 1
fi

# ─── 7. Launch container ──────────────────────────────────────────
if [ "${DEBUG_MODE}" = "1" ]; then
    # Debug mode: run directly in terminal (no tmux)
    echo -e "${YELLOW}🔧 Debug mode: running container directly in terminal${NC}"
    echo -e ""
    bash "${TMP_SCRIPT}"
else
    # Normal mode: run in tmux
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

    tmux attach -t "${SESSION_NAME}"
fi
