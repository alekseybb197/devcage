#!/bin/bash
# entrypoint.sh — обёртка над qwen, логирует сессию через script

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

# Формат файла .cast (JSON-based, без шума)
SESSION_CAST="${LOG_DIR}/session-$(date +%Y%m%d-%H%M%S).cast"
echo "📝 Запись сессии: ${SESSION_CAST}"

# --stdin: записывать ввод пользователя
# --command: команда для запуска
# Логи сразу видны на хосте если директория смонтирована через -v
asciinema rec --stdin "${SESSION_CAST}" -c "qwen"
# After the session finishes, copy the session log
# After the session finishes, copy the session log
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="${HOME}/.qwen/tmp"

# Find the most recent logs.json in ~/.qwen/tmp/
LATEST_TMP_DIR=$(ls -t "${TMP_DIR}"/*/logs.json 2>/dev/null | head -1 | xargs -I{} dirname {})
if [[ -z "${LATEST_TMP_DIR}" ]]; then
  echo "Ошибка: не найдены папки в ${TMP_DIR}" >&2
  exit 1
fi
LOGS_FILE="${LATEST_TMP_DIR}/logs.json"
if [[ ! -f "${LOGS_FILE}" ]]; then
  echo "Ошибка: не найден logs.json в ${LATEST_TMP_DIR}" >&2
  exit 1
fi

# Find the newest .cast session file
LATEST_SESSION=$(ls -t "${LOG_DIR}"/*.cast 2>/dev/null | head -1)
if [[ -z "${LATEST_SESSION}" ]]; then
  echo "Ошибка: не найдены файлы сессий в ${LOG_DIR}" >&2
  exit 1
fi

OUTPUT_FILE="${LATEST_SESSION%.cast}.json"
cp "${LOGS_FILE}" "${OUTPUT_FILE}"
echo "Скопировано: ${LOGS_FILE} -> ${OUTPUT_FILE}"
# Plain‑text conversion disabled (cast file kept)
