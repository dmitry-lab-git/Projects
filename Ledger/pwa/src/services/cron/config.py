cat > src/services/cron/config.py <<'PY'
# === Пути (твои из файла) ===
MAIN_BACKUP_DIR = "/mnt/c/Personal/Projects/Archive/db_dump_files"
ARCHIVE_DIR = "/mnt/c/Personal/Projects/Archive/db_dump_files/Archive"
BACKUP_DIR = "/mnt/c/Personal/Projects/Archive/db_dump_files"

# === Расписание (ЕДИНЫЙ ИСТОЧНИК ПРАВДЫ) ===
# Формат: "минута час" или полный cron
CRON_SCHEDULE = {
    "readme_updater": "0 0 * * *",      # 00:00 каждый день
    "ledger_backup": "0 22 * * *",       # TIME_LEDGER="0 22"
    "household_backup": "10 22 * * *",   # TIME_HOUSEHOLD="10 22"
    "git_backup": "20 22 * * *",         # TIME_GIT="20 22"
    "archive_move": "40 22 * * *",       # TIME_ARCHIVE="40 22"
    "clean_old": "50 22 * * *",          # TIME_CLEAN="50 22"
    "inspector": "0 21 * * 4",            # TIME_INSPECTOR="0 21 * * 4" четверг
}

# Python джобы (APScheduler)
PYTHON_JOBS = ["readme_updater"]

# Bash джобы (из папки \wsl...\jobs или /mnt/c/...)
BASH_JOBS = {
    "ledger_backup": "backup_ledger.sh",
    "household_backup": "backup_household.sh",
    "git_backup": "backup_git.sh",
    "archive_move": "archive.sh",
    "clean_old": "clean.sh",
}
PY