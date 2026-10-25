@echo off
:: Кодировка UTF-8, чтобы корректно отображался русский текст в консоли
chcp 65001 > nul

echo ====================================================
echo      ЗАПУСК ПОЛНОЙ ИНИЦИАЛИЗАЦИИ БЭКАПОВ (WSL)
echo ====================================================
echo.

echo [1/3] Запуск резервного копирования Git...
wsl /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump.sh
echo.

echo [2/3] Запуск резервного копирования БД Household...
wsl /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump_household.sh
echo.

echo [3/3] Запуск резервного копирования БД Ledger...
wsl /bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump_git.sh
echo.

echo ====================================================
echo   Все процессы резервного копирования завершены!
echo ====================================================
timeout /t 3
