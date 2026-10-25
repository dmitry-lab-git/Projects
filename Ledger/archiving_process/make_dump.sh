#!/bin/bash

# Точный путь к файлу секретов во внешней папке
SECRET_FILE="/home/fujitsu-u745/Projects/secure_folder/postgre_sql/credentials.conf"

# Проверка доступности файла
if [ ! -f "$SECRET_FILE" ]; then
    echo "ОШИБКА: Файл секретов не найден в secure_folder!"
    exit 1
fi

# Импортируем доступы
source "$SECRET_FILE"

DBNAME="ledger"

# Новый формат даты с днем недели на конце: ДДММГГ_ДеньНедели (например: 151026_Thu)
DATE_FORMAT=$(date +%d%m%y_%a)
BACKUP_PATH="${BACKUP_DIR}/${DBNAME}_${DATE_FORMAT}.dump"

echo "Запуск резервного копирования базы данных ${DBNAME}..."

# Выполняем дамп
PGPASSWORD=$PGPASSWORD pg_dump -U $PGUSER -h $PGHOST -d $DBNAME -F c -b -v -f "$BACKUP_PATH"

if [ $? -eq 0 ]; then
    echo "Резервная копия успешно создана: $BACKUP_PATH"
else
    echo "ОШИБКА: Не удалось создать дамп базы данных!"
    exit 1
fi

# --- БЛОК ВСПЛЫВАЮЩЕГО УВЕДОМЛЕНИЯ WINDOWS ---
powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Резервное копирование Git-репозиториев завершено успешно!', 0, 'Git Backup', 64)" > /dev/null
