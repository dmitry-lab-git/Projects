cat > ~/Projects/Ledger/pwa/src/services/cron/jobs/weekly_inspection.sh <<'SH'
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_FILE="$SCRIPT_DIR/schedule.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "ОШИБКА: Файл конфигурации schedule.conf не найден в $SCRIPT_DIR"
    exit 1
fi

source "$CONF_FILE"

# Регистрируем все 6 процессов
(
echo "$TIME_LEDGER * * * /bin/bash $SCRIPT_DIR/make_dump.sh"
echo "$TIME_HOUSEHOLD * * * /bin/bash $SCRIPT_DIR/make_dump_household.sh"
echo "$TIME_GIT * * * /bin/bash $SCRIPT_DIR/make_dump_git.sh"
echo "$TIME_ARCHIVE * * * /bin/bash $SCRIPT_DIR/archive_untouchable.sh"
echo "$TIME_CLEAN * * * /bin/bash $SCRIPT_DIR/clean_and_rotate.sh"
echo "$TIME_INSPECTOR /bin/bash $SCRIPT_DIR/weekly_inspection.sh"
) | crontab -

echo "Расписание CRON успешно обновлено для всех 6 постоянных процессов из $SCRIPT_DIR"
crontab -l
SH
chmod +x ~/Projects/Ledger/pwa/src/services/cron/jobs/weekly_inspection.sh