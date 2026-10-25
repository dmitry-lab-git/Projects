import reflex as rx
from pwa.db import household_engine
from sqlalchemy import text
from datetime import date, timedelta
import calendar
from collections import defaultdict


def plural_ru(n: int, forms: tuple[str, str, str]) -> str:
    """Функция склонения слов после числительных в русском языке."""
    n = abs(n) % 100
    n1 = n % 10
    if 11 <= n <= 14:
        return forms[2]
    if n1 == 1:
        return forms[0]
    if 2 <= n1 <= 4:
        return forms[1]
    return forms[2]


class MedicineReportState(rx.State):
    # ==============================================================================
    # 1. ПОЛЯ ДЛЯ ВКЛАДКИ №1 (АКТУАЛЬНЫЕ СХЕМЫ ПРИЕМА)
    # ==============================================================================
    active_schemes_rows: list[dict] = []

    # ==============================================================================
    # 2. ПОЛЯ ДЛЯ ВКЛАДКИ №2 (ТЕКУЩИЙ СТАТУС ЗА 2 МЕСЯЦА)
    # ==============================================================================
    month1_num: int = date.today().month
    year1: int = date.today().year

    month2_num: int = (date.today().month - 2) % 12 + 1
    year2: int = date.today().year - (1 if date.today().month == 1 else 0)

    MONTH_NAMES = {
        1: "Январь", 2: "Февраль", 3: "Март", 4: "Апрель", 5: "Май", 6: "Июнь",
        7: "Июль", 8: "Август", 9: "Сентябрь", 10: "Октябрь", 11: "Ноябрь", 12: "Декабрь"
    }

    current_active: list[dict] = []
    current_completed: list[dict] = []

    # ==============================================================================
    # 3. ПОЛЯ ДЛЯ ВКЛАДКИ №3 (АРХИВ ЗА ПРОИЗВОЛЬНЫЙ ПЕРИОД)
    # ==============================================================================
    start_date: str = ""
    end_date: str = ""
    archive_rows: list[dict] = []

    # ==============================================================================
    # 4. ВЫЧИСЛЯЕМЫЕ СВОЙСТВА (RX.VAR)
    # ==============================================================================
    @rx.var
    def month1_label(self) -> str:
        return f"{self.MONTH_NAMES.get(self.month1_num)} {self.year1}"

    @rx.var
    def month2_label(self) -> str:
        return f"{self.MONTH_NAMES.get(self.month2_num)} {self.year2}"

    # ==============================================================================
    # 5. СОБЫТИЯ И ЖИЗНЕННЫЙ ЦИКЛ (RX.EVENT)
    # ==============================================================================
    @rx.event
    def on_mount(self):
        if not self.start_date:
            self.start_date = (date.today() - timedelta(days=14)).isoformat()
        if not self.end_date:
            self.end_date = date.today().isoformat()
        self.fetch_archive()
        self.load_all_reports()

    @rx.event
    def load_all_reports(self):
        self.load_active_schemes()
        self.load_current_status_matrix()

    @rx.event
    def set_start_date(self, val: str):
        self.start_date = val

    @rx.event
    def set_end_date(self, val: str):
        self.end_date = val

    @rx.event
    def fetch_archive(self):
        if not self.start_date or not self.end_date:
            return

        with household_engine.connect() as conn:
            query = text("""
                SELECT 
                    s.name AS supplement_name,
                    s.brand,
                    s.unit_type,
                    SUM(i.amount) AS total_amount,
                    COUNT(DISTINCT i.intake_date) AS days_count
                FROM medicine.intakes i
                JOIN medicine.supplements s ON i.supplement_id = s.id
                WHERE i.intake_date BETWEEN :start_d AND :end_d
                GROUP BY s.id, s.name, s.brand, s.unit_type
                ORDER BY total_amount DESC;
            """)

            results = conn.execute(query, {
                "start_d": date.fromisoformat(self.start_date),
                "end_d": date.fromisoformat(self.end_date)
            }).fetchall()

            archive_list = []
            for row in results:
                tot = row.total_amount or 0
                days = row.days_count or 0
                avg_dose = round(tot / days, 1) if days > 0 else 0.0

                unit_raw = (row.unit_type or "таблетка").lower()
                if "капс" in unit_raw:
                    unit_form = plural_ru(tot, ("капсула", "капсулы", "капсул"))
                else:
                    unit_form = plural_ru(tot, ("таблетка", "таблетки", "таблеток"))

                days_form = plural_ru(days, ("день", "дня", "дней"))

                archive_list.append({
                    "supplement_name": row.supplement_name,
                    "brand": row.brand or "—",
                    "total_amount": f"{tot} {unit_form}",
                    "days_count": f"{days} {days_form}",
                    "average_dose": f"{avg_dose} {unit_form}/день"
                })

            self.archive_rows = archive_list

    @rx.event
    def load_active_schemes(self):
        today = date.today()
        with household_engine.connect() as conn:
            schemes_query = text("""
                SELECT 
                    s.name AS supplement_name,
                    s.brand,
                    s.unit_type,
                    sch.target_daily_amount,
                    sch.start_date,
                    sch.end_date
                FROM medicine.schedules sch
                JOIN medicine.supplements s ON sch.supplement_id = s.id
                WHERE sch.status = 'active' AND (sch.end_date IS NULL OR sch.end_date >= :today)
                ORDER BY s.name ASC;
            """)
            results = conn.execute(schemes_query, {"today": today}).fetchall()

            active_schemes = []
            for row in results:
                unit_raw = (row.unit_type or "таблетка").lower()
                target_amount = row.target_daily_amount
                if "капс" in unit_raw:
                    unit_form = plural_ru(target_amount, ("капсула", "капсулы", "капсул"))
                else:
                    unit_form = plural_ru(target_amount, ("таблетка", "таблетки", "таблеток"))

                dose_str = f"{target_amount} {unit_form}/день"
                start_str = row.start_date.strftime("%d.%m.%Y") if row.start_date else "—"
                end_str = row.end_date.strftime("%d.%m.%Y") if row.end_date else "Бессрочно"

                if row.end_date and row.start_date:
                    total_days = (row.end_date - row.start_date).days + 1
                    passed_days = (today - row.start_date).days + 1
                    passed_days = max(0, min(passed_days, total_days))
                    left_days = max(0, (row.end_date - today).days)

                    total_days_form = plural_ru(total_days, ("день", "дня", "дней"))
                    left_days_form = plural_ru(left_days, ("день", "дня", "дней"))

                    course_str = f"{passed_days} из {total_days} {total_days_form} (осталось {left_days} {left_days_form})"
                else:
                    course_str = "Бессрочно"

                active_schemes.append({
                    "supplement_name": row.supplement_name,
                    "brand": row.brand or "—",
                    "dose_str": dose_str,
                    "course_str": course_str,
                    "date_range": f"{start_str} — {end_str}"
                })

            self.active_schemes_rows = active_schemes

    def _calc_month_stats(self, month_first_day, month_last_day, schedule, intakes_by_date, today):
        days_in_month = calendar.monthrange(month_first_day.year, month_first_day.month)[1]

        month_intakes = [
            amount for intake_date, amount in intakes_by_date.items()
            if month_first_day <= intake_date <= month_last_day
        ]
        fact_total = sum(month_intakes)
        days_count = len(month_intakes)

        if schedule:
            s_start = schedule['start_date']
            s_end = schedule['end_date'] if schedule['end_date'] else today

            active_start = max(month_first_day, s_start)
            active_end = min(month_last_day, s_end, today)
            active_days = max(0, (active_end - active_start).days + 1)
        else:
            active_days = 0

        if schedule and active_days > 0 and schedule['target_daily_amount'] > 0:
            expected = schedule['target_daily_amount'] * active_days
            compliance = round((fact_total / expected) * 100) if expected > 0 else 0
            if compliance > 100:
                compliance = 100
        else:
            compliance = 0

        return {
            "fact": fact_total,
            "days_count": days_count,
            "days_in_month": days_in_month,
            "active_days": active_days,
            "compliance": compliance
        }

    @rx.event
    def load_current_status_matrix(self):
        today = date.today()

        m1_first = date(self.year1, self.month1_num, 1)
        m1_last = date(self.year1, self.month1_num, calendar.monthrange(self.year1, self.month1_num)[1])

        m2_first = date(self.year2, self.month2_num, 1)
        m2_last = date(self.year2, self.month2_num, calendar.monthrange(self.year2, self.month2_num)[1])

        with household_engine.connect() as conn:
            supplements = conn.execute(text("SELECT id, name, brand, unit_type FROM medicine.supplements ORDER BY name;")).fetchall()

            schedules_raw = conn.execute(text("""
                SELECT supplement_id, start_date, end_date, target_daily_amount, status::text 
                FROM medicine.schedules;
            """)).fetchall()

            schedules_map = {}
            for sch in schedules_raw:
                schedules_map[sch.supplement_id] = {
                    "start_date": sch.start_date,
                    "end_date": sch.end_date,
                    "target_daily_amount": sch.target_daily_amount or 0,
                    "status": sch.status,
                }

            intakes_raw = conn.execute(text("""
                SELECT supplement_id, intake_date, amount 
                FROM medicine.intakes 
                WHERE intake_date BETWEEN :m2_start AND :m1_end;
            """), {"m2_start": m2_first, "m1_end": m1_last}).fetchall()

            intakes_map = defaultdict(lambda: defaultdict(int))
            for row in intakes_raw:
                intakes_map[row.supplement_id][row.intake_date] += row.amount

            all_items = []

            for supp in supplements:
                sid = supp.id
                sch = schedules_map.get(sid)
                supp_intakes = intakes_map.get(sid, {})

                if not sch and not supp_intakes:
                    continue

                m1_stats = self._calc_month_stats(m1_first, m1_last, sch, supp_intakes, today)
                m2_stats = self._calc_month_stats(m2_first, m2_last, sch, supp_intakes, today)

                end_date = sch.get("end_date") if sch else None
                if end_date and end_date < today:
                    computed_status = "Завершен"
                elif sch and sch.get("status") == "active":
                    computed_status = "Активен"
                else:
                    computed_status = "Без схемы"

                unit_raw = (supp.unit_type or "таблетка").lower()

                # Склонения для М1 и М2 факта
                if "капс" in unit_raw:
                    m1_unit_form = plural_ru(m1_stats["fact"], ("капсула", "капсулы", "капсул"))
                    m2_unit_form = plural_ru(m2_stats["fact"], ("капсула", "капсулы", "капсул"))
                else:
                    m1_unit_form = plural_ru(m1_stats["fact"], ("таблетка", "таблетки", "таблеток"))
                    m2_unit_form = plural_ru(m2_stats["fact"], ("таблетка", "таблетки", "таблеток"))

                # Склонение и сокращение для суточной нормы и тултипа
                if sch:
                    target = sch['target_daily_amount']
                    if "капс" in unit_raw:
                        short_unit = "капс."
                        full_unit = plural_ru(target, ("капсула", "капсулы", "капсул"))
                    else:
                        short_unit = "таб."
                        full_unit = plural_ru(target, ("таблетка", "таблетки", "таблеток"))
                    
                    dose_str = f"{target} {short_unit}/день"
                    dose_tooltip = f"{target} {full_unit}/день"
                else:
                    dose_str = "—"
                    dose_tooltip = "—"

                row_data = {
                    "supplement_name": supp.name,
                    "brand": supp.brand or "—",
                    "m1_unit_form": m1_unit_form,
                    "m2_unit_form": m2_unit_form,
                    "dose_str": dose_str,
                    "m1_dose_str": dose_str,
                    "m2_dose_str": dose_str,
                    "m1_dose_tooltip": dose_tooltip,
                    "m2_dose_tooltip": dose_tooltip,
                    "computed_status": computed_status,
                    "badge_type": "completed" if computed_status == "Завершен" else ("active" if computed_status == "Активен" else "no_schedule"),
                    "end_date": end_date,

                    "m1_fact": m1_stats["fact"],
                    "m1_days_str": f"{m1_stats['days_count']}/{m1_stats['days_in_month']}",
                    "m1_active_days": m1_stats["active_days"],
                    "m1_compliance": m1_stats["compliance"],

                    "m2_fact": m2_stats["fact"],
                    "m2_days_str": f"{m2_stats['days_count']}/{m2_stats['days_in_month']}",
                    "m2_active_days": m2_stats["active_days"],
                    "m2_compliance": m2_stats["compliance"],
                }

                all_items.append(row_data)

            def sort_key(item):
                return item.get("m1_fact", 0)

            active_sorted = sorted(
                [i for i in all_items if i["computed_status"] == "Активен"],
                key=sort_key,
                reverse=True
            )

            without_scheme_sorted = sorted(
                [i for i in all_items if i["computed_status"] == "Без схемы"],
                key=sort_key,
                reverse=True
            )

            completed_sorted = sorted(
                [i for i in all_items if i["computed_status"] == "Завершен"],
                key=lambda x: x.get("end_date") or date.min,
                reverse=True
            )

            self.current_active = active_sorted + without_scheme_sorted
            self.current_completed = completed_sorted