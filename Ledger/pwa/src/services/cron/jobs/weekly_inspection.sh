cat > ~/Projects/Ledger/pwa/src/services/cron/jobs/weekly_inspection.sh <<'SH'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/schedule.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "ОШИБКА: Файл конфигурации schedule.conf не найден!"
    exit 1
fi

source "$CONF_FILE"

echo "=== ЗАПУСК ПЛАНОВОЙ ПРОВЕРКИ АРХИВНОЙ СИСТЕМЫ ==="

COUNT_DAILY=$(find "$MAIN_BACKUP_DIR" -maxdepth 1 -type f \( -name "*.dump" -o -name "*.bundle" \) 2>/dev/null | wc -l)
COUNT_ARCHIVE=$(find "$ARCHIVE_DIR" -maxdepth 1 -type f \( -name "*.dump" -o -name "*.bundle" \) 2>/dev/null | wc -l)

powershell.exe -Command "
\$msg = 'Выполняется плановая еженедельная проверка инфраструктуры бэкапов.' + [char]13 +
        '' + [char]13 +
        'Текущий статус хранилища (Google Drive):' + [char]13 +
        '• В основной папке (Daily): $COUNT_DAILY файлов.' + [char]13 +
        '• В папке архива (Mon): $COUNT_ARCHIVE файлов.' + [char]13 +
        '' + [char]13 +
        'ИНСТРУКЦИЯ ДЛЯ РУЧНОЙ ВЕРИФИКАЦИИ:' + [char]13 +
        '' + [char]13 +
        '1. Откройте рабочую директорию:' + [char]13 +
        '   C:\Personal\Projects\Archive\db_dump_files\' + [char]13 +
        '' + [char]13 +
        '2. Убедитесь, что в ней стабильно лежат файлы за последние 7 дней.' + [char]13 +
        '' + [char]13 +
        '3. Перейдите в изолированную папку:' + [char]13 +
        '   C:\Personal\Projects\Archive\db_dump_files\Archive\' + [char]13 +
        '' + [char]13 +
        '4. Проверьте наличие контрольных архивов с меткой _Mon (Понедельники).' + [char]13 +
        '' + [char]13 +
        'Регулярный контроль гарантирует полную сохранность данных Ledger Kernel.';
(New-Object -ComObject Wscript.Shell).Popup(\$msg, 0, 'Еженедельный контроль инфраструктуры бэкапов', 64)
" > /dev/null 2>&1 || true

echo "Плановая проверка завершена успешно. Daily: $COUNT_DAILY, Archive: $COUNT_ARCHIVE"
SH
chmod +x ~/Projects/Ledger/pwa/src/services/cron/jobs/weekly_inspection.sh

# Отдельный установщик cron - чтобы не путать с инспекцией
cat > ~/Projects/Ledger/pwa/src/services/cron/jobs/deploy_cron.sh <<'SH'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/schedule.conf"

(
echo "$TIME_LEDGER * * * /bin/bash $SCRIPT_DIR/make_dump.sh"
echo "$TIME_HOUSEHOLD * * * /bin/bash $SCRIPT_DIR/make_dump_household.sh"
echo "$TIME_GIT * * * /bin/bash $SCRIPT_DIR/make_dump_git.sh"
echo "$TIME_ARCHIVE * * 1 /bin/bash $SCRIPT_DIR/archive_untouchable.sh"
echo "$TIME_CLEAN * * 2 /bin/bash $SCRIPT_DIR/clean_and_rotate.sh"
echo "$TIME_INSPECTOR * * 0 /bin/bash $SCRIPT_DIR/weekly_inspection.sh"
) | crontab -

echo "CRON обновлен:"
crontab -l
SH
chmod +x ~/Projects/Ledger/pwa/src/services/cron/jobs/deploy_cron.sh