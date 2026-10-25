import reflex as rx
from pwa.db import household_engine
from pwa.models import SupplementCatalog, SupplementIntake, ObservationLog
from sqlalchemy import select, text
import uuid
from datetime import datetime, date

class MedicineState(rx.State):
    supplements: list[dict] = []
    intakes: list[dict] = []
    observations: list[dict] = []

    # Выпадающие списки / выбранные значения
    selected_supplement_name: str = ""

    # Управление датой приема
    use_current_date: bool = True
    selected_date: str = ""

    # Новые наблюдения / фильтры
    observation_date_str: str = date.today().isoformat()
    observation_notes: str = ""

    @rx.var
    def today_date_str(self) -> str:
        return date.today().isoformat()

    @rx.var
    def current_datetime_str(self) -> str:
        return datetime.now().strftime("%Y-%m-%dT%H:%M")
    @rx.var
    def supplement_names(self) -> list[str]:
        return [s.get("name", "") for s in self.supplements if "name" in s]
    @rx.event
    def set_selected_supplement_name(self, val: str):
        self.selected_supplement_name = val
    @rx.event
    def set_selected_date(self, val: str):
        self.selected_date = val

    @rx.event
    def set_use_current_date(self, val: bool):
        self.use_current_date = val
    @rx.event
    def set_observation_date_str(self, val: str):
        self.observation_date_str = val
    @rx.event
    def set_observation_notes(self, val: str):
        self.observation_notes = val
    @rx.event
    def load_medicine_data(self):
        with household_engine.connect() as conn:
            # 1. Загрузка справочника добавок
            supps = conn.execute(select(SupplementCatalog).order_by(SupplementCatalog.name)).mappings().all()
            self.supplements = [
                {
                    "id": str(s["id"]),
                    "name": s["name"] or "",
                    "brand": s["brand"] or "",
                    "unit_type": s["unit_type"] or "таблетка",
                }
                for s in supps
            ]
        self.load_intakes()
        self.load_observations()

    @rx.event
    def load_intakes(self):
        with household_engine.connect() as conn:
            query = text("""
                SELECT 
                    i.id,
                    i.intake_date,
                    s.name AS supplement_name,
                    s.unit_type,
                    i.amount,
                    i.created_at
                FROM medicine.intakes i
                LEFT JOIN medicine.supplements s ON i.supplement_id = s.id
                ORDER BY i.intake_date DESC
                LIMIT 50
            """)
            results = conn.execute(query).fetchall()

            self.intakes = [
                {
                    "id": str(row.id),
                    "intake_date": str(row.intake_date)[:16] if row.intake_date else "—",
                    "supplement_name": str(row.supplement_name) if row.supplement_name else "—",
                    "unit_type": str(row.unit_type) if row.unit_type else "таблетка",
                    "amount": str(row.amount),
                }
                for row in results
            ]

    @rx.event
    def load_observations(self):
        with household_engine.connect() as conn:
            query = text("""
                SELECT 
                    id,
                    observation_date,
                    notes,
                    created_at
                FROM medicine.observations
                ORDER BY observation_date DESC
                LIMIT 50
            """)
            results = conn.execute(query).fetchall()

            self.observations = [
                {
                    "id": str(row.id),
                    "observation_date": str(row.observation_date) if row.observation_date else "—",
                    "notes": str(row.notes) if row.notes else "—",
                }
                for row in results
            ]

    @rx.event
    def add_supplement(self, form_data: dict):
        with household_engine.begin() as conn:
            conn.execute(
                SupplementCatalog.__table__.insert().values(
                    id=uuid.uuid4(),
                    name=form_data["name"],
                    brand=form_data.get("brand"),
                    unit_type=form_data.get("unit_type", "таблетка")
                )
            )
        self.load_medicine_data()
        return rx.window_alert("Препарат добавлен в справочник!")

    @rx.event
    def add_intake(self, form_data: dict):
        supp_name = self.selected_supplement_name
        supp = next((s for s in self.supplements if s.get("name") == supp_name), None)

        if not supp:
            return rx.window_alert("Ошибка: Препарат не выбран!")

        if self.use_current_date:
            intake_d = date.today()
        else:
            raw_date = form_data.get("intake_date")
            try:
                intake_d = datetime.strptime(raw_date, "%Y-%m-%d").date() if raw_date else date.today()
            except ValueError:
                intake_d = date.today()

        with household_engine.begin() as conn:
            conn.execute(
                SupplementIntake.__table__.insert().values(
                    id=uuid.uuid4(),
                    supplement_id=supp["id"],
                    intake_date=intake_d,
                    amount=int(form_data.get("amount", 1))
                )
            )

        # Сбрасываем выбранный препарат и возвращаем флаг текущей даты в True
        self.selected_supplement_name = ""
        self.use_current_date = True
        self.selected_date = ""
        self.load_intakes()
        return rx.window_alert("Факт приема зарегистрирован!")
    @rx.event
    def save_observation(self, form_data: dict):
        obs_date_str = form_data.get("observation_date") or self.observation_date_str
        notes = form_data.get("notes") or self.observation_notes

        try:
            obs_date = datetime.strptime(obs_date_str, "%Y-%m-%d").date()
        except ValueError:
            obs_date = date.today()

        with household_engine.begin() as conn:
            # Обычный INSERT — теперь можно добавлять сколько угодно наблюдений за день
            conn.execute(
                text("""
                    INSERT INTO medicine.observations (id, observation_date, notes)
                    VALUES (:id, :obs_date, :notes)
                """),
                {
                    "id": uuid.uuid4(),
                    "obs_date": obs_date,
                    "notes": notes
                }
            )

        # Очищаем поле заметок и сбрасываем дату на сегодняшнюю
        self.observation_notes = ""
        self.observation_date_str = date.today().isoformat()

        self.load_observations()
        return rx.window_alert("Запись в дневник наблюдений добавлена!")

