#!/usr/bin/env bash
#
# scripts/deploy.sh — Скрипт деплоя веб-сайта
#

set -uo pipefail

DEPLOY_HOST="${DEPLOY_HOST:-devops}"
DEPLOY_TARGET_DIR="${DEPLOY_TARGET_DIR:-/var/www/devops-site}"
DEPLOY_SOURCE_DIR="${DEPLOY_SOURCE_DIR:-site}"
SMOKE_URL="${SMOKE_URL:-https://devops.local}"

DRY_RUN=false
VERBOSE=false

show_help() {
    cat << 'HELP_EOF'
Использование: ./scripts/deploy.sh [ОПЦИИ]

Опции:
  -n, --dry-run          Тестовый запуск без фактической передачи файлов
  -v, --verbose          Подробный вывод процесса синхронизации
  --target-dir DIR       Целевой каталог на сервере (по умолчанию: /var/www/devops-site)
  --source-dir DIR       Исходный каталог на хосте (по умолчанию: site)
  -h, --help             Показать эту справку и выйти
HELP_EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --target-dir)
            DEPLOY_TARGET_DIR="$2"
            shift 2
            ;;
        --source-dir)
            DEPLOY_SOURCE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Ошибка: неизвестный параметр: $1" >&2
            exit 1
            ;;
    esac
done

echo "=== Запуск сценария деплоя ==="
echo "Хост: $DEPLOY_HOST"
echo "Источник: $DEPLOY_SOURCE_DIR"
echo "Целевой каталог: $DEPLOY_TARGET_DIR"

# 1. Проверка наличия каталога и index.html
if [[ ! -d "$DEPLOY_SOURCE_DIR" ]] || [[ ! -f "$DEPLOY_SOURCE_DIR/index.html" ]]; then
    echo "Ошибка: обязательный файл '$DEPLOY_SOURCE_DIR/index.html' не найден!" >&2
    exit 1
fi

# 2. Проверка Git: рабочая копия в site/ должна быть чистой (без незакоммиченных изменений)
if [[ -d .git ]] && [[ -n "$(git status --porcelain "$DEPLOY_SOURCE_DIR")" ]]; then
    echo "Ошибка: каталог '$DEPLOY_SOURCE_DIR' содержит незафиксированные изменения в Git!" >&2
    echo "Зафиксируйте изменения коммитом перед деплоем." >&2
    exit 1
fi

# 3. Проверка доступности хоста по SSH
echo "Проверка доступности хоста '$DEPLOY_HOST' через SSH..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$DEPLOY_HOST" "true" 2>/dev/null; then
    echo "Ошибка: хост '$DEPLOY_HOST' недоступен по SSH!" >&2
    exit 1
fi
echo "SSH подключение успешно."

# 4. Выполнение rsync
RSYNC_CMD=("rsync" "-a" "--delete" "--chmod=D755,F644" "-e" "ssh")

if [[ "$VERBOSE" = true ]]; then
    RSYNC_CMD+=("-v")
fi

if [[ "$DRY_RUN" = true ]]; then
    RSYNC_CMD+=("-n")
    echo ">> Режим DRY-RUN (файлы не будут изменены)"
fi

SRC_PATH="${DEPLOY_SOURCE_DIR%/}/"
DEST_PATH="${DEPLOY_HOST}:${DEPLOY_TARGET_DIR%/}/"

echo "Выполнение синхронизации rsync..."
if ! "${RSYNC_CMD[@]}" "$SRC_PATH" "$DEST_PATH"; then
    echo "Ошибка: сбой синхронизации rsync!" >&2
    exit 1
fi

if [[ "$DRY_RUN" = true ]]; then
    echo "Dry-run завершён успешно."
    exit 0
fi

# 5. Проверка доступности веб-сервера (smoke test)
echo "Выполнение проверки доступности ($SMOKE_URL)..."
HTTP_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "$SMOKE_URL" || echo "000")

if [[ "$HTTP_STATUS" != "200" ]]; then
    echo "Ошибка: проверка доступности не пройдена! HTTP статус: $HTTP_STATUS (ожидался 200)" >&2
    exit 1
fi

echo "Проверка доступности успешно пройдена (HTTP status: 200)."
echo "=== Деплой успешно завершён ==="
exit 0
