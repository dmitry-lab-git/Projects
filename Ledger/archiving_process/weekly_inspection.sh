#!/bin/bash

# Импортируем пути к папкам бэкапов
CONF_FILE="/home/fujitsu-u745/Projects/Ledger/archiving_process/schedule.conf"
if [ -f "$CONF_FILE" ]; then source "$CONF_FILE"; fi

echo "=== ЗАПУСК ПЛАНОВОЙ ПРОВЕРКИ АРХИВНОЙ СИСТЕМЫ ==="

# Сбор статистики из папок (считаем файлы)
COUNT_DAILY=$(find "$MAIN_BACKUP_DIR" -maxdepth 1 -type f \( -name "*.dump" -o -name "*.bundle" \) 2>/dev/null | wc -l)
COUNT_ARCHIVE=$(find "$ARCHIVE_DIR" -maxdepth 1 -type f \( -name "*.dump" -o -name "*.bundle" \) 2>/dev/null | wc -l)

# Формируем красивое многострочное сообщение для Windows с жесткими отступами [char]13
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
" > /dev/null

echo "Плановая проверка завершена успешно."
