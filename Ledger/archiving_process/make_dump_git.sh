#!/bin/bash

# Точный путь к файлу секретов во внешней папке (берем оттуда только BACKUP_DIR)
SECRET_FILE="/home/fujitsu-u745/Projects/secure_folder/postgre_sql/credentials.conf"

if [ ! -f "$SECRET_FILE" ]; then
    echo "ОШИБКА: Файл конфигурации не найден в secure_folder!"
    exit 1
fi

source "$SECRET_FILE"

# Список ваших Git-проектов и точные пути к их репозиториям в WSL
declare -A REPOSITORIES
REPOSITORIES["projects_root"]="/home/fujitsu-u745/Projects"

# Формат даты с днем недели на конце: ДДММГГ_ДеньНедели (например: 151026_Thu)
DATE_FORMAT=$(date +%d%m%y_%a)

# Перебираем все репозитории из списка
for REPO_NAME in "${!REPOSITORIES[@]}"; do
    REPO_PATH="${REPOSITORIES[$REPO_NAME]}"
    
    echo "Запуск резервного копирования Git-репозитория: ${REPO_NAME}..."
    
    # Проверяем, существует ли папка и является ли она Git-репозиторием
    if [ -d "${REPO_PATH}/.git" ]; then
        BACKUP_PATH="${BACKUP_DIR}/${REPO_NAME}_${DATE_FORMAT}.bundle"
        
        # Переходим в папку проекта и создаем bundle всего репозитория (всех веток)
        cd "$REPO_PATH" || exit
        git bundle create "$BACKUP_PATH" --all > /dev/null
        
        if [ $? -eq 0 ]; then
            echo "Резервная копия Git успешно создана: $BACKUP_PATH"
        else
            echo "ОШИБКА: Не удалось создать bundle для ${REPO_NAME}!"
        fi
    else
        echo "ОШИБКА: Путь ${REPO_PATH} не существует или не является Git-репозиторием!"
    fi
done

# --- БЛОК ВСПЛЫВАЮЩЕГО УВЕДОМЛЕНИЯ WINDOWS ---
powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Резервное копирование основной базы данных Ledger завершено успешно!', 0, 'PostgreSQL Backup: Ledger', 64)" > /dev/null
