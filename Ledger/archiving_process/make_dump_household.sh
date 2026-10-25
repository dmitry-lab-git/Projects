#!/bin/bash

SECRET_FILE="/home/fujitsu-u745/Projects/secure_folder/postgre_sql/credentials.conf"

if [ ! -f "$SECRET_FILE" ]; then
    echo "ОШИБКА: Файл секретов не найден в secure_folder!"
    exit 1
fi

source "$SECRET_FILE"

DBNAME="household"

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

# --- БЛОК АВТОМАТИЧЕСКОЙ РОТАЦИИ (РАЗРЕЖЕННОСТЬ ДЛЯ HOUSEHOLD) ---
echo "Запуск прореживания старых дампов базы ${DBNAME}..."
find "$BACKUP_DIR" -type f -name "${DBNAME}_*.dump" -mtime +7 | while read -r file; do
    # Если файлу больше 7 дней и в имени НЕТ Понедельника (_Mon) — удаляем
    if [[ "$file" != *_Mon.* ]]; then
        rm -f "$file"
        echo "Удален старый ежедневный дамп: $file"
    fi
done

# --- БЛОК ВСПЛЫВАЮЩЕГО УВЕДОМЛЕНИЯ WINDOWS ---
powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Резервное копирование базы данных Household завершено успешно!', 0, 'PostgreSQL Backup: Household', 64)" > /dev/null
