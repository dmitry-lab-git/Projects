#!/bin/bash
set -e
echo "[RESTORE] Восстанавливаем WSL окружение..."
sudo cp wsl.conf /etc/wsl.conf
sudo apt update
sudo apt install -y postgresql postgresql-contrib cron python3-pip
sudo systemctl enable cron
sudo systemctl start cron
cat CRON.txt | crontab -
echo "[RESTORE] Готово. Cron:"
crontab -l
echo "[RESTORE] Теперь восстанови БД: psql -f ~/Projects/db/ledger/full_schema.sql"
