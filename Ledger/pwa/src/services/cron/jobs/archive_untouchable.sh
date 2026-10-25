cat > ~/Projects/Ledger/pwa/src/services/cron/jobs/archive_untouchable.sh <<'SH'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

echo "=== ЗАПУСК АРХИВАЦИИ НЕПРИКАСАЕМЫХ ФАЙЛОВ ==="
mkdir -p "$ARCHIVE_DIR"

FLAG_FILE="$SCRIPT_DIR/archive_success.flag"
rm -f "$FLAG_FILE"

FILES_MOVED=0

# Находим файлы за Понедельник и перемещаем
while IFS= read -r file; do
    [ -z "$file" ] && continue
    echo "Перенос файла в долгосрочный архив: $(basename "$file")"
    mv -f "$file" "$ARCHIVE_DIR/"
    FILES_MOVED=1
done < <(find "$MAIN_BACKUP_DIR" -maxdepth 1 -type f -name "*_Mon.*")

echo "Архивация успешно выполнена: $(date)" > "$FLAG_FILE"
echo "Квитанция создана: $FLAG_FILE, перенесено: $FILES_MOVED"
SH
chmod +x ~/Projects/Ledger/pwa/src/services/cron/jobs/archive_untouchable.sh
echo "Патч применен:"
cat ~/Projects/Ledger/pwa/src/services/cron/jobs/archive_untouchable.sh