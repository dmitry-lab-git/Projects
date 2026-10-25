#!/bin/bash

CONF_FILE="/home/fujitsu-u745/Projects/Ledger/archiving_process/schedule.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "ОШИБКА: Файл конфигурации schedule.conf не найден!"
    exit 1
fi

source "$CONF_FILE"

# Регистрируем все 6 процессов в системный cron
(
echo "$TIME_GIT * * * /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump.sh"
echo "$TIME_HOUSEHOLD * * * /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump_household.sh"
echo "$TIME_LEDGER * * * /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump_git.sh"
echo "$TIME_ARCHIVE * * * /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/archive_untouchable.sh"
echo "$TIME_CLEAN * * * /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/clean_and_rotate.sh"
echo "$TIME_INSPECTOR /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/weekly_inspection.sh"
) | crontab -

echo "Расписание CRON успешно обновлено для всех 6 постоянных процессов!"
