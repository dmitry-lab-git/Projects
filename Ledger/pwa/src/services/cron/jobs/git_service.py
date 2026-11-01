"""
Service for automatic Git actions (commit and push) for system metrics updates.
"""
import os
import subprocess
import logging

logger = logging.getLogger(__name__)

REPO_DIR = "/home/fujitsu-u745/Projects"

def run_git_push(files_to_add: list, commit_message: str):
    """
    Выполняет git add для переданного списка файлов, делает коммит и пушит в репозиторий.
    """
    try:
        # Переходим в директорию репозитория
        os.chdir(REPO_DIR)
        
        # Проверяем статус git только для целевых файлов
        status_res = subprocess.run(["git", "status", "--porcelain"] + files_to_add, capture_output=True, text=True, check=True)
        if not status_res.stdout.strip():
            logger.info(f"CRON Git: Нет изменений для файлов {files_to_add}. Пропуск коммита.")
            return False

        # Добавляем файлы
        subprocess.run(["git", "add"] + files_to_add, check=True)
        
        # Делаем коммит
        subprocess.run(["git", "commit", "-m", commit_message], check=True)
        
        # Пушим в origin main
        subprocess.run(["git", "push", "origin", "main"], check=True)
        logger.info(f"CRON Git: Изменения файлов {files_to_add} успешно отправлены в GitHub.")
        return True
        
    except subprocess.CalledProcessError as e:
        logger.error(f"CRON Git Ошибка выполнения команд для {files_to_add}: {e}")
        return False
    except Exception as e:
        logger.error(f"CRON Git Непредвиденная ошибка: {e}")
        return False
