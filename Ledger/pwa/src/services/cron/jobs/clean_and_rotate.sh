cat > ~/Projects/Ledger/pwa/src/services/cron/jobs/clean_and_rotate.sh <<'SH'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

echo "=== ЗАПУСК ОЧИСТКИ ЕЖЕДНЕВНЫХ БЭКАПОВ ==="

FLAG_FILE="$SCRIPT_DIR/archive_success.flag"
CURRENT_DAY=$(date +%a)

# --- БЛОК ЗАЩИТЫ ---
if [[ "$CURRENT_DAY" == "Mon" || "$CURRENT_DAY" == "Tue" ]]; then
    if [ ! -f "$FLAG_FILE" ]; then
        echo "КРИТИЧЕСКАЯ ОШИБКА: Флаг архивации не найден! Очистка заблокирована."
        powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('ВНИМАНИЕ! Скрипт архивации понедельников не отработал! Очистка хранилища заблокирована для предотвращения потери данных.', 0, 'КРИТИЧЕСКИЙ СБОЙ: Инфраструктура Бэкапов', 16)" > /dev/null 2>&1 || true
        exit 1
    fi
fi

find "$MAIN_BACKUP_DIR" -maxdepth 1 -type f \( -name "*.dump" -o -name "*.bundle" \) -mtime +7 | while read -r file; do
    [ -z "$file" ] && continue
    echo "Удаление старого ежедневного файла: $(basename "$file")"
    rm -f "$file"
done

rm -f "$FLAG_FILE"

powershell.exe -Command "(New-Object -ComObject Wscript.Shell).Popup('Обслуживание хранилища завершено. Старые ежедневные копии удалены.', 0, 'Хранилище Бэкапов', 64)" > /dev/null 2>&1 || true

echo "Очистка завершена успешно."
SH
chmod +x ~/Projects/Ledger/pwa/src/services/cron/jobs/clean_and_rotate.sh