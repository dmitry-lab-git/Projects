import reflex as rx
from datetime import datetime
from typing import List, Optional
from sqlalchemy import text
from pwa.models.time_tracker import TimeEntryItem


class TimeTrackerState(rx.State):
    """
    Управление состоянием тайм-трекера, фиксацией интервалов
    и оффлайн-синхронизацией данных в базе данных Household.
    """
    
    entries: List[TimeEntryItem] = []
    is_loading: bool = False
    error_message: Optional[str] = None
    
    current_task_name: str = ""
    current_comment: str = ""
    
    active_timer_id: Optional[str] = None

    @rx.var
    def has_active_timer(self) -> bool:
        """Вычисляемое свойство: запущен ли таймер прямо сейчас."""
        return self.active_timer_id is not None

    def change_task_name(self, name: str):
        """Изменение названия текущей задачи из инпута."""
        self.current_task_name = name

    def change_comment(self, comment: str):
        """Изменение комментария к текущему интервалу."""
        self.current_comment = comment

    # Метод change_context удален, так как контекста больше нет

    def load_data(self):
        """Загружает актуальный лог времени из схемы infrastructure базы household."""
        self.is_loading = True
        self.error_message = None
        
        try:
            from pwa.db import household_engine 
            
            with household_engine.connect() as conn:
                result = conn.execute(text("""
                    SELECT id, task_name, start_time, end_time, comment, is_deleted, updated_at
                    FROM infrastructure.time_tracker
                    WHERE is_deleted = FALSE
                    ORDER BY start_time DESC
                """))
                rows = result.mappings().all()
                
            self.entries = [TimeEntryItem.from_orm(row) for row in rows]
            
            active = next((e for e in self.entries if e.end_time is None), None)
            if active:
                self.active_timer_id = str(active.id)  
                self.current_task_name = active.task_name
                # ИСПРАВЛЕНО: Строка self.current_context = active.context полностью удалена
                self.current_comment = active.comment or ""
                
        except Exception as e:
            import traceback
            traceback.print_exc()
            self.error_message = "Не удалось загрузить историю фиксации времени."
        finally:
            self.is_loading = False

    def start_timer(self):
        """Запуск нового интервала времени в базе household."""
        if not self.current_task_name.strip():
            self.error_message = "Имя задачи не может быть пустым."
            return
            
        if self.has_active_timer:
            self.error_message = "Сначала остановите текущий активный таймер."
            return

        import uuid
        from pwa.db import household_engine
        
        new_id = str(uuid.uuid4())
        now = datetime.utcnow()
        
        try:
            with household_engine.begin() as conn:
                conn.execute(
                    text("""
                        INSERT INTO infrastructure.time_tracker 
                            (id, task_name, start_time, end_time, comment, updated_at)
                        VALUES 
                            (:id, :task_name, :start_time, NULL, :comment, :updated_at)
                    """),
                    {
                        "id": new_id,
                        "task_name": self.current_task_name.strip(),
                        "start_time": now,
                        "comment": self.current_comment.strip() or None,
                        "updated_at": now
                    }
                )
            
            self.active_timer_id = new_id
            self.load_data()
            
        except Exception as e:
            import traceback
            traceback.print_exc()
            self.error_message = "Ошибка при запуске таймера в базе данных."

    def stop_timer(self):
        """Остановка текущего активного таймера в базе household."""
        if not self.has_active_timer:
            return

        from pwa.db import household_engine
        now = datetime.utcnow()
        
        try:
            with household_engine.begin() as conn:
                conn.execute(
                    text("""
                        UPDATE infrastructure.time_tracker
                        SET end_time = :end_time,
                            comment = :comment,
                            updated_at = :updated_at
                        WHERE id = :id AND end_time IS NULL
                    """),
                    {
                        "id": self.active_timer_id,
                        "end_time": now,
                        "comment": self.current_comment.strip() or None,
                        "updated_at": now
                    }
                )
            
            self.active_timer_id = None
            self.current_task_name = ""
            self.current_comment = ""
            self.load_data()
            
        except Exception as e:
            import traceback
            traceback.print_exc()
            self.error_message = "Ошибка при остановке таймера."
