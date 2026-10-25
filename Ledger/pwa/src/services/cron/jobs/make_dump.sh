#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

SECRET_FILE="/home/fujitsu-u745/Projects/secure_folder/postgre_sql/credentials.conf"

if [ ! -f "$SECRET_FILE" ]; then
    echo "ОШИБКА: Файл секретов не найден в secure_folder!"
    exit 1
fi

source "$SECRET_FILE"

DBNAME="ledger"
DATE_FORMAT=$(date +%d%m%y_%a)
BACKUP_PATH="${BACKUP_DIR}/${DBNAME}_${DATE_FORMAT}.dump"

echo "Запуск резервного копирования базы данных ${DBNAME}..."

PGPASSWORD=$PGPASSWORD pg_dump -U $PGUSER -h $PGHOST -d $DBNAME -F c -b -v -f "$BACKUP_PATH"

echo "Резервная копия успешно создана: $BACKUP_PATH"

powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Резервное копирование БД Ledger завершено успешно!', 0, 'Ledger Backup', 64)" > /dev/null 2>&1 || true
