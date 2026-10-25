import reflex as rx
import asyncio
import json
from typing import List, Dict, Any
from sqlalchemy import create_engine, text
from dotenv import load_dotenv
import os

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:password@localhost:5432/ledger_db")

try:
    engine = create_engine(DATABASE_URL, pool_size=5, max_overflow=10, pool_timeout=30)
except Exception as e:
    print(f"Ошибка инициализации пула БД: {e}")
    engine = None

class AuditState(rx.State):
    """Стейт дашборда с пошаговым графиком и исторической таблицей сессий."""
    pending_count: int = 0
    processing_count: int = 0
    processed_count: int = 0
    pause_count: int = 0
    trust_score: float = 0.0
    
    raw_log_text: str = "Ожидание запуска мониторинга..."
    selected_raw_response_str: str = "Здесь отобразится raw_response последней транзакции."
    
    # Списки данных для UI компонентов
    chart_data: List[Dict[str, Any]] = []
    # Формат строк: "seq||iteration_type||status||processed_count||avg_trust"
    sessions_table_flat: List[str] = []
    
    is_running: bool = False
    db_error_msg: str = ""

    @rx.var
    def total_tx(self) -> int:
        return self.pending_count + self.processing_count + self.processed_count + self.pause_count

    @rx.var
    def progress_percent(self) -> int:
        total = self.total_tx
        if total == 0:
            return 0
        return int((self.processed_count / total) * 100)

    def toggle_audit(self):
        self.is_running = not self.is_running
        if self.is_running:
            return AuditState.run_db_polling

    @rx.event(background=True)
    async def run_db_polling(self):
        AUDIT_SESSIONS = [
            "27798216-b5c1-4c65-8c52-2f408a5995a6",
            "8e2e2a04-1fa1-4264-afc3-556755a6ac83",
            "13ac9166-4b14-49c2-9346-d5094708507d",
            "e1042b5c-e212-4ee2-9fac-6f2cbddcae87"
        ]
        CURRENT_AUDIT_ID = "e1042b5c-e212-4ee2-9fac-6f2cbddcae87"

        while True:
            if not self.is_running:
                break
            if not engine:
                async with self:
                    self.db_error_msg = "Пул базы данных не инициализирован."
                    self.is_running = False
                break

            try:
                with engine.connect() as conn:
                    # 1. Метрики текущей очереди
                    stats_query = text("""
                        SELECT audit_status, COUNT(*) FROM audit.audit_process_queue GROUP BY audit_status;
                    """)
                    result = conn.execute(stats_query).fetchall()
                    
                    counts = {"pending": 0, "processing": 0, "processed": 0, "pause": 0}
                    for row in result:
                        status, count = row[0], row[1]
                        if status in counts:
                            counts[status] = count

                    # 2. Средний Trust Score текущей сессии
                    trust_query = text("""
                        SELECT COALESCE(AVG((raw_response->>'trust_score')::numeric), 0.0)
                        FROM audit.staging_audit_results WHERE audit_id = :audit_id;
                    """)
                    trust_res = conn.execute(trust_query, {"audit_id": CURRENT_AUDIT_ID}).fetchone()
                    current_trust = round(float(trust_res[0]), 2) if trust_res and trust_res[0] is not None else 0.0

                    # 3. Лента логов (Последние 3 записи)
                    log_query = text("""
                        SELECT transaction_id, code, status, reasoning, raw_response 
                        FROM audit.staging_audit_results WHERE audit_id = :audit_id
                        ORDER BY created_at DESC LIMIT 3;
                    """)
                    log_rows = conn.execute(log_query, {"audit_id": CURRENT_AUDIT_ID}).fetchall()
                    
                    lines = []
                    latest_json_str = "Нет доступных raw_response."
                    for idx, row in enumerate(log_rows):
                        tx_id = str(row[0])
                        code = str(row[1]) if row[1] is not None else "—"
                        reasoning = str(row[3]) if row[3] else "Без описания"
                        lines.append(f"• Код {code} | ID: {tx_id}\n  Аргументация: {reasoning}\n")
                        
                        if idx == 0:
                            raw_data = row[4] if row[4] else {}
                            if isinstance(raw_data, str):
                                try: raw_data = json.loads(raw_data)
                                except: pass
                            latest_json_str = json.dumps(raw_data, indent=2, ensure_ascii=False)
                    final_log_text = "\n".join(lines) if lines else "В базе пока нет записей."

                    # 4. Пошаговый график текущей сессии (по 30 транзакций)
                    chart_query = text("""
                        WITH numbered_results AS (
                            SELECT 
                                (raw_response->>'trust_score')::numeric as t_score,
                                ROW_NUMBER() OVER (ORDER BY created_at ASC) as row_num
                            FROM audit.staging_audit_results WHERE audit_id = :audit_id
                        )
                        SELECT ((row_num - 1) / 30) + 1 as batch_num, ROUND(AVG(t_score), 2) as avg_score
                        FROM numbered_results GROUP BY batch_num ORDER BY batch_num ASC;
                    """)
                    chart_res = conn.execute(chart_query, {"audit_id": CURRENT_AUDIT_ID}).fetchall()
                    local_chart = []
                    for row in chart_res:
                        b_num = row[0]
                        score = row[1]
                        local_chart.append({"name": f"Тх {b_num*30-29}-{b_num*30}", "Trust Score": round(float(score), 2) if score else 0.0})

                    # 5. НОВЫЙ ЗАПРОС: Агрегация исторических данных сессий для таблицы
                    sessions_query = text("""
                        SELECT 
                            s.seq,
                            s.iteration_type,
                            s.status,
                            COUNT(r.staging_id) as processed_count,
                            COALESCE(AVG((r.raw_response->>'trust_score')::numeric), 0.0) as avg_trust
                        FROM audit.audit_sessions s
                        LEFT JOIN audit.staging_audit_results r ON s.id = r.audit_id
                        WHERE s.id IN (:id1, :id2, :id3, :id4)
                        GROUP BY s.id, s.seq, s.iteration_type, s.status, s.created_at
                        ORDER BY s.seq ASC, s.created_at ASC;
                    """)
                    sessions_res = conn.execute(sessions_query, {
                        "id1": AUDIT_SESSIONS[0], "id2": AUDIT_SESSIONS[1],
                        "id3": AUDIT_SESSIONS[2], "id4": AUDIT_SESSIONS[3]
                    }).fetchall()

                    flat_table_rows = []
                    for row in sessions_res:
                        s_seq = str(row[0]) if row[0] is not None else "—"
                        s_type = str(row[1]) if row[1] else "—"
                        s_status = str(row[2]) if row[2] else "—"
                        s_processed = str(row[3])
                        s_trust = str(round(float(row[4]), 2)) if row[4] else "0.0"
                        
                        # Собираем плоскую строку для React
                        flat_table_rows.append(f"{s_seq}||{s_type}||{s_status}||{s_processed}||{s_trust}")

                    # Запись пачки данных в UI
                    async with self:
                        self.pending_count = counts["pending"]
                        self.processing_count = counts["processing"]
                        self.processed_count = counts["processed"]
                        self.pause_count = counts["pause"]
                        self.trust_score = current_trust
                        self.raw_log_text = final_log_text
                        self.selected_raw_response_str = latest_json_str
                        self.chart_data = local_chart
                        self.sessions_table_flat = flat_table_rows
                        self.db_error_msg = ""

            except Exception as db_err:
                async with self:
                    self.db_error_msg = f"Ошибка базы данных: {str(db_err)}"
                    self.is_running = False
                break

            await asyncio.sleep(1)
def status_card(title: str, count: int, color_scheme: str, icon: str) -> rx.Component:
    return rx.card(
        rx.hstack(
            rx.vstack(rx.text(title, size="2", color_scheme="gray"), rx.heading(f"{count}", size="5"), align_items="start"),
            rx.spacer(),
            rx.box(rx.icon(tag=icon, size=22), padding="2", border_radius="md", background_color=rx.color(color_scheme, 3), color=rx.color(color_scheme, 11)),
            align="center", width="100%",
        ), size="2",
    )

def render_table_row(flat_str: str) -> rx.Component:
    """Отрисовка строки таблицы сессий из плоской строки с использованием rx.cond."""
    parts = flat_str.split("||")
    
    # ИСПРАВЛЕНО: Заменяем Python-if на нативный rx.cond для динамического цвета бейджа
    status_badge_color = rx.cond(parts[2] == "finished", "indigo", "green")
    
    return rx.table.row(
        rx.table.cell(parts[0], weight="bold"),
        rx.table.cell(parts[1]),
        rx.table.cell(rx.badge(parts[2], color_scheme=status_badge_color)),
        rx.table.cell(parts[3], justify="end"),
        rx.table.cell(parts[4], justify="end", weight="medium"),
    )

def index() -> rx.Component:
    btn_color = rx.cond(AuditState.is_running, "red", "indigo")
    btn_text = rx.cond(AuditState.is_running, "Приостановить мониторинг", "Запустить мониторинг БД")
    
    return rx.box(
        rx.vstack(
            rx.hstack(
                rx.vstack(rx.heading("Диспетчер Очереди Аудита (AIVE)", size="6"), rx.text("Прямая трансляция метрик и аналитика сессий", size="2", color_scheme="gray"), align_items="start"),
                rx.cond(AuditState.is_running, rx.badge("Соединен", color_scheme="green", variant="surface"), rx.badge("Пауза", color_scheme="gray", variant="surface")),
                justify="between", align="center", width="100%",
            ),

            rx.cond(AuditState.db_error_msg != "", rx.callout(AuditState.db_error_msg, icon="alert_octagon", color_scheme="red", width="100%")),

            rx.grid(
                status_card("В ожидании (pending)", AuditState.pending_count, "amber", "clock"),
                status_card("В работе (processing)", AuditState.processing_count, "blue", "refresh_cw"),
                status_card("Успешно (processed)", AuditState.processed_count, "green", "check_check"),
                status_card("Средний Trust Score", AuditState.trust_score, "indigo", "shield"),
                columns="2", spacing="3", width="100%",
            ),

            rx.card(
                rx.vstack(
                    rx.hstack(rx.text("Процент очистки очереди", size="2", weight="medium"), rx.text(f"{AuditState.progress_percent}%", size="2", weight="bold"), justify="between", width="100%"),
                    rx.progress(value=AuditState.progress_percent, size="2", width="100%", color_scheme="green"),
                    width="100%", spacing="2",
                ), width="100%",
            ),

            # График (с шагом по 30 транзакций)
            rx.card(
                rx.vstack(
                    rx.heading("Динамика Trust Score текущей сессии (Шаг: 30 Tx)", size="3"),
                    rx.recharts.line_chart(
                        rx.recharts.line(data_key="Trust Score", stroke="#5e6ad2", stroke_width=2),
                        rx.recharts.x_axis(data_key="name", font_size="10px"),
                        rx.recharts.y_axis(domain=[0, 10], font_size="10px"),
                        rx.recharts.graphing_tooltip(),
                        data=AuditState.chart_data, height=180, width="100%",
                    ),
                    width="100%", spacing="2",
                ), width="100%",
            ),

            # Инспектор JSONB
            rx.card(
                rx.vstack(
                    rx.heading("Детализация raw_response последней транзакции", size="3"),
                    rx.box(
                        rx.text(AuditState.selected_raw_response_str, style={"white-space": "pre-wrap", "font-family": "monospace", "font-size": "11px"}),
                        width="100%", max_height="180px", overflow_y="auto", padding="2", background_color=rx.color("gray", 1), border_radius="sm"
                    ),
                    align_items="start", width="100%", spacing="2"
                ), width="100%"
            ),

            # Живой лог
            rx.card(
                rx.vstack(
                    rx.heading("Живой поток очереди (Последние 3 записи)", size="3"),
                    rx.box(rx.text(AuditState.raw_log_text, style={"white-space": "pre-wrap", "font-size": "12px", "line-height": "1.4"}), width="100%", max_height="140px", overflow_y="auto"),
                    align_items="start", width="100%", spacing="1"
                ), width="100%"
            ),

            # ТАБЛИЦА АНАЛИТИКИ СЕССИЙ (Вывод в самом низу)
            rx.card(
                rx.vstack(
                    rx.heading("Сравнительный анализ сессий аудита", size="3"),
                    rx.table.root(
                        rx.table.header(
                            rx.table.row(
                                rx.table.column_header_cell("Seq"),
                                rx.table.column_header_cell("Тип итерации"),
                                rx.table.column_header_cell("Статус"),
                                rx.table.column_header_cell("Обработано (Tx)", justify="end"),
                                rx.table.column_header_cell("Средний Trust", justify="end"),
                            )
                        ),
                        rx.table.body(
                            rx.foreach(AuditState.sessions_table_flat, render_table_row)
                        ),
                        width="100%",
                        size="1",
                    ),
                    width="100%",
                    spacing="2",
                ),
                width="100%",
            ),

            rx.button(btn_text, on_click=AuditState.toggle_audit, color_scheme=btn_color, size="3", width="100%"),
            spacing="4", padding="5", max_width="700px", margin="0 auto",
        ),
        background_color=rx.color("gray", 2), min_height="100vh",
    )

app = rx.App(theme=rx.theme(appearance="dark", accent_color="indigo", radius="medium"))
app.add_page(index, route="/")
