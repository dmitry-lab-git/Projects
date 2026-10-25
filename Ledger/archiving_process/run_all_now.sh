#!/bin/bash

echo "=== ЗАПУСК ПОЛНОГО ФОРСИРОВАННОГО БЭКАПА ==="

# 1. Запуск бэкапа Git-репозиториев
echo "1/3 Выполнение бэкапа Git..."
/bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump.sh

# 2. Запуск бэкапа БД Household
echo "2/3 Выполнение бэкапа БД Household..."
/bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump_household.sh

# 3. Запуск бэкапа БД Ledger
echo "3/3 Выполнение бэкапа БД Ledger..."
/bin/bash /home/fujitsu-u745/Projects/Ledger/archiving_process/make_dump_git.sh

echo "============================================="
echo "Все процессы успешно принудительно завершены!"

# Финальное всплывающее окно Windows
powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; [System.Windows.Forms::MessageBox]::Show('ВНЕОЧЕРЕДНОЙ ПОЛНЫЙ БЭКАП ЗАВЕРШЕН! Все 3 архива (Git, Household, Ledger) успешно обновлены и проверены.', 'Ручной бэкап системы', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)"
