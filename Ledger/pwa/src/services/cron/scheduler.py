import atexit
import logging
import subprocess
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from .config import CRON_SCHEDULE, MAIN_BACKUP_DIR
from src.services.cron.jobs.readme_updater import update_readme_metrics

logger = logging.getLogger(__name__)
_scheduler = None

# Маппинг python-функций
PY_JOBS_MAP = {
    "readme_updater": update_readme_metrics,
}

def get_scheduler():
    global _scheduler
    if _scheduler is None:
        _scheduler = BackgroundScheduler(timezone="Asia/Almaty")
    return _scheduler

def parse_cron(cron_str: str):
    parts = cron_str.split()
    if len(parts) == 2:  # формат "0 22" -> "0 22 * * *"
        return CronTrigger(minute=parts[0], hour=parts[1])
    elif len(parts) == 5:
        return CronTrigger.from_crontab(cron_str)
    else:
        raise ValueError(f"Invalid cron: {cron_str}")

def setup_cron():
    scheduler = get_scheduler()
    if scheduler.get_jobs():
        logger.info("APScheduler: already registered")
        return scheduler

    for job_id, cron_expr in CRON_SCHEDULE.items():
        trigger = parse_cron(cron_expr)
        
        if job_id in PY_JOBS_MAP:
            scheduler.add_job(
                PY_JOBS_MAP[job_id],
                trigger,
                id=job_id,
                replace_existing=True,
                misfire_grace_time=3600,
            )
            logger.info(f"Registered PY job: {job_id} @ {cron_expr}")

        # Bash джобы тоже можно гонять через APScheduler (опционально)
        # else: 
        #     scheduler.add_job(run_bash_job, trigger, args=[job_id], id=job_id)

    if not scheduler.running:
        scheduler.start()
        logger.info(f"APScheduler started with {len(scheduler.get_jobs())} jobs")
        atexit.register(lambda: scheduler.shutdown(wait=False))

    return scheduler

def run_bash_job(job_name: str):
    script_path = f"{MAIN_BACKUP_DIR}/{job_name}.sh"
    logger.info(f"Running bash job: {script_path}")
    subprocess.run(["bash", script_path], check=False)