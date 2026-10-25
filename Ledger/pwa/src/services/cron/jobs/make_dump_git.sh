#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

SECRET_FILE="/home/fujitsu-u745/Projects/secure_folder/postgre_sql/credentials.conf"

if [ ! -f "$SECRET_FILE" ]; then
    echo "ОШИБКА: Файл конфигурации не найден в secure_folder!"
    exit 1
fi

source "$SECRET_FILE"

declare -A REPOSITORIES
REPOSITORIES["projects_root"]="/home/fujitsu-u745/Projects"

DATE_FORMAT=$(date +%d%m%y_%a)

for REPO_NAME in "${!REPOSITORIES[@]}"; do
    REPO_PATH="${REPOSITORIES[$REPO_NAME]}"
    echo "Запуск резервного копирования Git-репозитория: ${REPO_NAME}..."

    # Проверяем, что это git репо или что внутри есть репозитории
    if [ -d "${REPO_PATH}/.git" ]; then
        BACKUP_PATH="${BACKUP_DIR}/${REPO_NAME}_${DATE_FORMAT}.bundle"
        cd "$REPO_PATH"
        git bundle create "$BACKUP_PATH" --all > /dev/null && echo "Git backup OK: $BACKUP_PATH" || echo "ОШИБКА: bundle для ${REPO_NAME}!"
    else
        # Если projects_root - ищем все .git внутри первого уровня и дампим каждый
        echo "Ищем репозитории внутри $REPO_PATH..."
        find "$REPO_PATH" -maxdepth 3 -type d -name ".git" | while read -r gitdir; do
            REPO_DIR=$(dirname "$gitdir")
            NAME=$(basename "$REPO_DIR")
            BACKUP_PATH="${BACKUP_DIR}/${NAME}_${DATE_FORMAT}.bundle"
            echo " -> bundle $NAME"
            cd "$REPO_DIR" && git bundle create "$BACKUP_PATH" --all > /dev/null 2>&1 && echo "OK $BACKUP_PATH" || echo "FAIL $NAME"
        done
    fi
done

powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Резервное копирование Git-репозиториев завершено успешно!', 0, 'Git Backup', 64)" > /dev/null 2>&1 || true
