import reflex as rx
from pwa.db import household_engine
from pwa.models import ResourceCatalog, MaterialDisposition, MeasuringDevice, DisposalPoint
from sqlalchemy import select, text
import uuid
from datetime import datetime, date

class InfrastructureState(rx.State):
    resources: list[dict] = []
    devices: list[dict] = [] 
    disposition_points: list[dict] = []
    disposition_history: list[dict] = []

    # Хранит список вариантов для выпадающего списка
    disposal_point_options: list[dict[str, str]] = []

    use_current_date: bool = True
    selected_date: str = ""

    # Добавляем переменные для хранения выбранных имен
    selected_resource_name: str = ""
    selected_device_name: str = ""
    selected_disposal_point_name: str = ""

    monthly_summary: list[dict] = []

    resource_summary: list[dict] = []

    # Новая переменная для фильтра месяца (формат "YYYY-MM")
    selected_month: str = date.today().strftime("%Y-%m")

    @rx.event
    def set_selected_month(self, val: str):
        self.selected_month = val
        self.load_monthly_summary()  # Пересчитываем сводку при смене месяца

    @rx.var
    def today_date_str(self) -> str:
        return date.today().isoformat()

    # Вычисляемые переменные для списка имен (с безопасным get)
    @rx.var
    def resource_names(self) -> list[str]:
        return [r.get("material_name", "") for r in self.resources if "material_name" in r]

    @rx.var
    def device_names(self) -> list[str]:
        return [d.get("device_name", "") for d in self.devices if "device_name" in d]

    @rx.var
    def disposition_point_names(self) -> list[str]:
        return [pt.get("display_name", "") for pt in self.disposition_points if "display_name" in pt]

    # Сеттеры для Select
    @rx.event
    def set_selected_resource_name(self, val: str):
        self.selected_resource_name = val

    @rx.event
    def set_selected_device_name(self, val: str):
        self.selected_device_name = val

    @rx.event
    def set_selected_disposal_point_name(self, val: str):
        self.selected_disposal_point_name = val

    # ДОБАВЛЕННЫЕ СЕТТЕРЫ ДЛЯ ДАТЫ И ЧЕКБОКСА:
    @rx.event
    def set_selected_date(self, val: str):
        self.selected_date = val

    @rx.event
    def set_use_current_date(self, val: bool):
        self.use_current_date = val

    @rx.event
    def load_resources(self):
        with household_engine.connect() as conn:
            # 1. Загрузка ресурсов
            res = conn.execute(select(ResourceCatalog)).mappings().all()
            self.resources = [
                {
                    "id": str(r["id"]),
                    "material_name": r["material_name"] or "",
                }
                for r in res
            ]
            
            # 2. Загрузка приборов
            dev = conn.execute(select(MeasuringDevice)).mappings().all()
            self.devices = [
                {
                    "id": str(d["id"]),
                    "device_name": d["device_name"] or "",
                }
                for d in dev
            ]
            
            # 3. Загрузка пунктов утилизации с формированием "Имя I Тип"
            pts = conn.execute(select(DisposalPoint)).mappings().all()
            self.disposition_points = []
            for pt in pts:
                name = pt["name"] or ""
                tp = pt["type"] or ""
                display_name = f"{name} I {tp}" if tp else name
                
                self.disposition_points.append({
                    "id": str(pt["id"]),
                    "name": name,
                    "type": tp,
                    "display_name": display_name,
                })
            
        self.load_disposition_history()
        self.load_monthly_summary()

    @rx.event
    def load_disposition_history(self):
        with household_engine.connect() as conn:
            query = text("""
                SELECT 
                    md.id,
                    md.created_at,
                    md.utilized_at,
                    rc.material_name,
                    d.device_name,
                    dp.name AS disposition_point_name,
                    md.quantity,
                    md.weighing_type
                FROM infrastructure.material_disposition md
                LEFT JOIN infrastructure.resource_catalog rc ON md.resource_id = rc.id
                LEFT JOIN infrastructure.measuring_devices d ON md.device_id = d.id
                LEFT JOIN infrastructure.disposal_points dp ON md.disposal_point = dp.id
                ORDER BY md.created_at DESC
                LIMIT 20
            """)
            results = conn.execute(query).fetchall()
            
            self.disposition_history = [
                {
                    "id": str(row.id),
                    # Обрезаем лишние секунды и миллисекунды (2026-09-04 17:25)
                    "created_at": str(row.created_at)[:16] if row.created_at else "—",
                    "utilized_at": str(row.utilized_at) if row.utilized_at else "—",
                    "material_name": str(row.material_name) if row.material_name else "—",
                    "device_name": str(row.device_name) if row.device_name else "—",
                    "disposition_point_name": str(row.disposition_point_name) if row.disposition_point_name else "—",
                    "quantity": str(row.quantity),
                    "weighing_type": str(row.weighing_type)
                }
                for row in results
            ]

    @rx.event
    def add_resource(self, form_data: dict):
        with household_engine.begin() as conn:
            conn.execute(
                ResourceCatalog.__table__.insert().values(
                    id=uuid.uuid4(),
                    material_name=form_data["material_name"],
                    resource_type=form_data.get("resource_type"),
                    default_unit=form_data.get("default_unit")
                )
            )
        self.load_resources()

    @rx.event
    def load_monthly_summary(self):
        try:
            target_date = datetime.strptime(self.selected_month, "%Y-%m").date() if self.selected_month else date.today()
        except ValueError:
            target_date = date.today()

        with household_engine.connect() as conn:
            # 1. Сводка по пунктам утилизации
            query_points = text("""
                SELECT 
                    dp.name AS point_name,
                    dp.type AS point_type,
                    SUM(md.quantity) AS total_mass,
                    COUNT(md.id) AS record_count
                FROM infrastructure.material_disposition md
                LEFT JOIN infrastructure.disposal_points dp ON md.disposal_point = dp.id
                WHERE date_trunc('month', md.utilized_at::timestamp) = date_trunc('month', CAST(:target_date AS TIMESTAMP))
                GROUP BY dp.id, dp.name, dp.type
                ORDER BY total_mass DESC
            """)
            results_points = conn.execute(query_points, {"target_date": target_date}).fetchall()
            
            self.monthly_summary = [
                {
                    "disposition_point_name": f"{row.point_name} I {row.point_type}" if row.point_type else (row.point_name or "Без пункта"),
                    "total_mass": f"{float(row.total_mass or 0):.3f} кг",
                    "record_count": f"{row.record_count} шт."
                }
                for row in results_points
            ]

            # 2. Сводка по ресурсам (material_name)
            query_resources = text("""
                SELECT 
                    COALESCE(rc.material_name, 'Неуказанный ресурс') AS resource_name,
                    rc.resource_type,
                    SUM(md.quantity) AS total_mass,
                    COUNT(md.id) AS record_count
                FROM infrastructure.material_disposition md
                LEFT JOIN infrastructure.resource_catalog rc ON md.resource_id = rc.id
                WHERE date_trunc('month', md.utilized_at::timestamp) = date_trunc('month', CAST(:target_date AS TIMESTAMP))
                GROUP BY rc.id, rc.material_name, rc.resource_type
                ORDER BY total_mass DESC
            """)
            results_resources = conn.execute(query_resources, {"target_date": target_date}).fetchall()

            self.resource_summary = [
                {
                    "resource_name": f"{row.resource_name} ({row.resource_type})" if row.resource_type else row.resource_name,
                    "total_mass": f"{float(row.total_mass or 0):.3f} кг",
                    "record_count": f"{row.record_count} шт."
                }
                for row in results_resources
            ]

    @rx.event
    def add_disposition(self, form_data: dict):
        # Используем переменные стейта для получения выбранных элементов выпадающих списков
        res_name = self.selected_resource_name
        dev_name = self.selected_device_name
        point_name = self.selected_disposal_point_name
        
        # Находим ID по имени (для пункта утилизации проверяем display_name)
        res = next((r for r in self.resources if r.get("material_name") == res_name), None)
        dev = next((d for d in self.devices if d.get("device_name") == dev_name), None)
        point = next((p for p in self.disposition_points if p.get("display_name") == point_name or p.get("name") == point_name), None)

        if not res:
            return rx.window_alert("Ошибка: Ресурс не выбран!")

        # Логика даты с учетом галочки "Использовать текущую дату"
        if self.use_current_date:
            utilized_date = date.today()
        else:
            raw_date = form_data.get("utilized_at")
            utilized_date = datetime.strptime(raw_date, "%Y-%m-%d").date() if raw_date else date.today()

        with household_engine.begin() as conn:
            conn.execute(
                MaterialDisposition.__table__.insert().values(
                    id=uuid.uuid4(),
                    resource_id=res["id"],
                    device_id=dev["id"] if dev else None,
                    disposal_point=point["id"] if point else None,
                    quantity=float(form_data.get("quantity", 0)),
                    weighing_type=form_data.get("weighing_type", "gross"),
                    utilized_at=utilized_date
                )
            )
            
        # Обновляем таблицу истории
        self.load_disposition_history()
        
        return rx.window_alert("Запись добавлена!")