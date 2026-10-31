import atexit
import logging
import subprocess
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger  # Добавили триггер интервалов
from apscheduler.jobstores.sqlalchemy import SQLAlchemyJobStore  # Добавили хранилище на диске
from .config import CRON_SCHEDULE, MAIN_BACKUP_DIR

# Импорты ваших python-функций
from src.services.cron.jobs.readme_updater import update_readme_metrics
from src.services.cron.jobs.metrics_updater import update_pwa_dashboard_metrics  # Наш новый джоб

logger = logging.getLogger(__name__)
_scheduler = None

# Маппинг python-функций — добавили новый обработчик
PY_JOBS_MAP = {
    "readme_updater": update_readme_metrics,
    "pwa_metrics_updater": update_pwa_dashboard_metrics,  # Зарегистрировали
}

def get_scheduler():
    global _scheduler
    if _scheduler is None:
        # Подключаем SQLite хранилище, чтобы планировщик помнил пропущенные запуски
        jobstores = {
            'default': SQLAlchemyJobStore(url='sqlite:///jobs.sqlite')
        }
        _scheduler = BackgroundScheduler(
            jobstores=jobstores,
            timezone="Asia/Almaty"
        )
    return _scheduler

def parse_trigger(schedule_str: str):
    """
    Парсит конфигурационную строку. Поддерживает как cron-форматы,
    так и интервальный запуск, например: 'interval 8h' или 'interval 24h'
    """
    schedule_str = schedule_str.strip()
    
    # Поддержка интервального запуска для работы "от старта приложения"
    if schedule_str.startswith("interval"):
        try:
            # Парсим что-то вроде "interval 8h" -> получаем число 8
            hours = int(schedule_str.split()[1].replace("h", ""))
            return IntervalTrigger(hours=hours)
        except (IndexError, ValueError):
            raise ValueError(f"Invalid interval format: {schedule_str}. Use 'interval Xh'")
            
    # Классический cron-формат
    parts = schedule_str.split()
    if len(parts) == 2:  # формат "0 22" -> "0 22 * * *"
        return CronTrigger(minute=parts[0], hour=parts[1], timezone="Asia/Almaty")
    elif len(parts) == 5:
        return CronTrigger.from_crontab(schedule_str, timezone="Asia/Almaty")
    else:
        raise ValueError(f"Invalid schedule expression: {schedule_str}")

def setup_cron():
    scheduler = get_scheduler()
    if scheduler.get_jobs():
        logger.info("APScheduler: already registered")
        return scheduler

    for job_id, schedule_expr in CRON_SCHEDULE.items():
        try:
            trigger = parse_trigger(schedule_expr)
        except ValueError as e:
            logger.error(f"Failed to parse schedule for {job_id}: {e}")
            continue
        
        if job_id in PY_JOBS_MAP:
            # Настраиваем параметры misfire под тип триггера
            # Для интервальных задач ставим большое окно, чтобы они гарантированно запустились при старте
            is_interval = schedule_expr.startswith("interval")
            grace_time = 28800 if is_interval else 3600  # 8 часов для интервалов, 1 час для крона

            scheduler.add_job(
                PY_JOBS_MAP[job_id],
                trigger,
                id=job_id,
                replace_existing=True,
                misfire_grace_time=grace_time,
                coalesce=True,  # Защита от накопления очереди при долгом простое приложения
            )
            logger.info(f"Registered PY job: {job_id} @ {schedule_expr} (coalesce=True)")

    if not scheduler.running:
        scheduler.start()
        logger.info(f"APScheduler started with {len(scheduler.get_jobs())} jobs")
        atexit.register(lambda: scheduler.shutdown(wait=False))

    return scheduler

def run_bash_job(job_name: str):
    script_path = f"{MAIN_BACKUP_DIR}/{job_name}.sh"
    logger.info(f"Running bash job: {script_path}")
    subprocess.run(["bash", script_path], check=False)
