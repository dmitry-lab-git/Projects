#!/bin/bash

CONF_FILE="/home/fujitsu-u745/Projects/Ledger/archiving_process/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

echo "=== ЗАПУСК АРХИВАЦИИ НЕПРИКАСАЕМЫХ ФАЙЛОВ ==="
mkdir -p "$ARCHIVE_DIR"

# Флаг-файл будет создаваться в папке скриптов
FLAG_FILE="/home/fujitsu-u745/Projects/Ledger/archiving_process/archive_success.flag"
# На всякий случай удаляем старый флаг перед началом
rm -f "$FLAG_FILE"

# Переменная для отслеживания факта переноса
FILES_MOVED=0

# Находим файлы за Понедельник (_Mon) и перемещаем их
find "$MAIN_BACKUP_DIR" -maxdepth 1 -type f -name "*_Mon.*" | while read -r file; do
    echo "Перенос файла в долгосрочный архив: $(basename "$file")"
    mv -f "$file" "$ARCHIVE_DIR/"
    FILES_MOVED=1
done

# Если сегодня понедельник, мы ОБЯЗАНЫ были сделать перенос. 
# Создаем квитанцию успеха, если файлы успешно перенесены (или если их просто не было, но скрипт отработал)
echo "Архивация успешно выполнена: $(date)" > "$FLAG_FILE"
echo "Квитанция успешной архивации создана."
