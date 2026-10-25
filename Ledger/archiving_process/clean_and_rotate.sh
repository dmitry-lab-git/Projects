#!/bin/bash

CONF_FILE="/home/fujitsu-u745/Projects/Ledger/archiving_process/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

echo "=== ЗАПУСК ОЧИСТКИ ЕЖЕДНЕВНЫХ БЭКАПОВ ==="

FLAG_FILE="/home/fujitsu-u745/Projects/Ledger/archiving_process/archive_success.flag"
CURRENT_DAY=$(date +%a)

# --- БЛОК ЗАЩИТЫ (FAULT TOLERANCE) ---
# Если сегодня вторник (после архивации в пн) или понедельник, проверяем флаг
if [[ "$CURRENT_DAY" == "Mon" || "$CURRENT_DAY" == "Tue" ]]; then
    if [ ! -f "$FLAG_FILE" ]; then
        echo "КРИТИЧЕСКАЯ ОШИБКА: Флаг архивации не найден! Очистка заблокирована."
        
        # Выводим критическое предупреждение в Windows
        powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('ВНИМАНИЕ! Скрипт архивации понедельников не отработал! Очистка хранилища заблокирована для предотвращения потери данных.', 0, 'КРИТИЧЕСКИЙ СБОЙ: Инфраструктура Бэкапов', 16)" > /dev/null
        exit 1
    fi
fi

# Если проверка прошла (или сегодня другой день недели), запускаем очистку
find "$MAIN_BACKUP_DIR" -maxdepth 1 -type f \( -name "*.dump" -o -name "*.bundle" \) -mtime +7 | while read -r file; do
    echo "Удаление старого ежедневного файла: $(basename "$file")"
    rm -f "$file"
done

# Удаляем использованный флаг до следующей недели
rm -f "$FLAG_FILE"

# Итоговое уведомление в Windows
powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Обслуживание хранилища завершено. Старые ежедневные копии удалены.', 0, 'Хранилище Бэкапов', 64)" > /dev/null

echo "Очистка завершена успешно."
