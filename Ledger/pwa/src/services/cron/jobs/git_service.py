"""
Service for automatic Git actions (commit and push) for system metrics updates.
"""
import os
import subprocess
import logging
import time

logger = logging.getLogger(__name__)

REPO_DIR = "/home/fujitsu-u745/Projects"

def run_git_push(files_to_add: list, commit_message: str):
    try:
        os.chdir(REPO_DIR)
        # Сначала проверяем что файлы реально существуют
        existing = [f for f in files_to_add if os.path.exists(os.path.join(REPO_DIR, f))]
        if not existing:
            logger.error(f"CRON Git: файлов не найдено в {REPO_DIR}: {files_to_add}")
            return False

        subprocess.run(["git", "add", "-f"] + existing, check=True)
        
        # Проверяем есть ли что коммитить
        result = subprocess.run(["git", "diff", "--cached", "--quiet"])
        if result.returncode != 0: # есть изменения
            subprocess.run(["git", "commit", "-m", commit_message], check=True)
        else:
            logger.info(f"CRON Git: нет изменений для {existing}, пропускаем коммит")
            return True
        
        for attempt in range(3):
            try:
                subprocess.run(["git", "push", "origin", "main"], check=True, timeout=60)
                logger.info(f"CRON Git: {existing} -> OK")
                return True
            except subprocess.CalledProcessError as e:
                logger.warning(f"CRON Git push неудачен (попытка {attempt + 1}): {e}")
                
                # Обработка non-fast-forward / удаленных изменений перед ретраем
                rebase_res = subprocess.run(["git", "pull", "--rebase", "origin", "main"], capture_output=True, text=True)
                if rebase_res.returncode != 0:
                    logger.warning(f"CRON Git pull --rebase warning: {rebase_res.stderr}")
                    subprocess.run(["git", "rebase", "--abort"], capture_output=True)
                
                time.sleep(5 * (attempt + 1))
                
        return False
    except Exception as e:
        logger.error(f"CRON Git Ошибка: {e}")
        return False