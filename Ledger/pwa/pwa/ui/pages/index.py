import reflex as rx
import logging
import json
import os

# Импортируем воркер для принудительного обновления
from src.services.cron.jobs.metrics_updater import update_pwa_dashboard_metrics

logger = logging.getLogger(__name__)

# Путь к файлу кэша метрик
METRICS_FILE = "assets/pwa_metrics.json"


class IndexState(rx.State):
    """Состояние для обработки ручного обновления и реактивного вывода метрик."""
    is_loading: bool = False
    
    # Поля для блока Digital
    transactions_count: str = "..."
    balance_snapshots: str = "..."
    verified_states: str = "..."
    pwa_staging_flow: str = "..."
    
    # Поля для блока Textile
    projects_implemented: str = "..."
    finished_products: str = "..."
    material_consumption: str = "..."
    
    # Метка времени последнего обновления
    last_updated: str = "неизвестно"

    def load_cached_metrics(self):
        """Чтение сохраненных метрик из JSON для отображения в UI."""
        if os.path.exists(METRICS_FILE):
            try:
                with open(METRICS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    
                    dig = data.get("digital", {})
                    self.transactions_count = str(dig.get("transactions", 0))
                    self.balance_snapshots = str(dig.get("balance_snapshots", 0))
                    self.verified_states = str(dig.get("verified_states", 0))
                    self.pwa_staging_flow = str(dig.get("pwa_staging_flow", 0))
                    
                    tex = data.get("textile", {})
                    self.projects_implemented = str(tex.get("projects_implemented", 0))
                    self.finished_products = str(tex.get("finished_products", 0))
                    self.material_consumption = f"{tex.get('material_consumption_m', 0.0)} п.м."
                    
                    self.last_updated = data.get("updated_at", "только что")
            except Exception as e:
                logger.error(f"Ошибка чтения кэша метрик: {e}")

    def trigger_manual_update(self):
        """Принудительный запуск обновления метрик кнопкой (обход 6-часового кэша)."""
        self.is_loading = True
        yield  # Включаем анимацию загрузки на кнопке

        try:
            update_pwa_dashboard_metrics(force=True)
            self.load_cached_metrics()  # Перечитываем свежие данные
            return rx.toast.success("Данные Hub успешно обновлены!")
        except Exception as e:
            logger.error(f"Ошибка ручного обновления: {e}")
            return rx.toast.error("Не удалось обновить метрики.")
        finally:
            self.is_loading = False


def metrics_dashboard() -> rx.Component:
    """Визуальные карточки метрик Digital и Textile."""
    return rx.grid(
        rx.card(
            rx.vstack(
                rx.hstack(rx.text("📊", size="5"), rx.heading("Digital (Core & Ledger)", size="4"), spacing="2"),
                rx.divider(),
                rx.text(f"• Транзакции (public.transactions): {IndexState.transactions_count}"),
                rx.text(f"• Снимки балансов (acc_balance_snapshot): {IndexState.balance_snapshots}"),
                rx.text(f"• Верифицированные состояния: {IndexState.verified_states}"),
                rx.text(f"• PWA Staging поток: {IndexState.pwa_staging_flow}"),
                align_items="start", spacing="1",
            ),
            width="100%",
        ),
        rx.card(
            rx.vstack(
                rx.hstack(rx.text("🧵", size="5"), rx.heading("Textile", size="4"), spacing="2"),
                rx.divider(),
                rx.text(f"• Реализовано проектов: {IndexState.projects_implemented}"),
                rx.text(f"• Готовых изделий: {IndexState.finished_products}"),
                rx.text(f"• Расход материалов: {IndexState.material_consumption}"),
                align_items="start", spacing="1",
            ),
            width="100%",
        ),
        columns="2",
        spacing="4",
        width="100%",
        margin_y="1em",
    )


def main_menu() -> rx.Component:
    return rx.hstack(
        rx.link(rx.button("Новая транзакция", variant="outline"), href="/new-transaction"),
        rx.link(rx.button("Справочники", variant="outline"), href="/dictionaries"),
        rx.link(rx.button("Снимки баланса", variant="outline"), href="/snapshots"),
        rx.link(rx.button("Активные счета", variant="outline"), href="/active-accounts"),
        rx.link(rx.button("Шаблоны транзакций", variant="outline"), href="/transaction-templates"),
        rx.link(rx.button("Сводка по параметрам", variant="outline"), href="/summary-report"),
        justify="start", spacing="3", wrap="wrap", width="100%",
    )


def household_menu() -> rx.Component:
    return rx.hstack(
        rx.link(rx.button("Утилизация отходов", variant="outline"), href="/infrastructure"),
        rx.link(
            rx.button("⏱️ Учет рабочего времени", variant="outline", color_scheme="grass"),
            href="/time-tracker",
        ),
        justify="start", spacing="3", wrap="wrap", width="100%",
    )


def medicine_menu() -> rx.Component:
    return rx.hstack(
        rx.link(rx.button("Управление медициной", variant="outline"), href="/medicine"),
        justify="start", spacing="3", wrap="wrap", width="100%",
    )


def projects_menu() -> rx.Component:
    return rx.hstack(
        rx.link(rx.button("Реестр проектов (Cross-DB)", variant="outline"), href="/projects"),
        justify="start", spacing="3", wrap="wrap", width="100%",
    )


@rx.page(route="/", on_load=IndexState.load_cached_metrics)
def index() -> rx.Component:
    return rx.container(
        rx.vstack(
            # Блок заголовка со встроенной кнопкой ручного обновления
            rx.hstack(
                rx.heading("Ledger PWA - Главное меню", size="6"),
                rx.spacer(),
                rx.vstack(
                    rx.button(
                        "🔄 Обновить Hub",
                        loading=IndexState.is_loading,
                        on_click=IndexState.trigger_manual_update,
                        variant="soft",
                        color_scheme="indigo",
                        size="2",
                    ),
                    rx.text(f"Синхронизировано: {IndexState.last_updated}", size="1", color_scheme="gray"),
                    align_items="end",
                    spacing="0",
                ),
                width="100%",
                align_items="center",
            ),
            
            # Подключаем карточки вывода метрик
            metrics_dashboard(),
            
            main_menu(),
            rx.divider(margin_y="1em"),

            rx.heading("Household PWA - Главное меню", size="6"),
            household_menu(),
            rx.divider(margin_y="1em"),

            rx.heading("Medicine PWA - Главное меню", size="6"),
            rx.hstack(
                rx.link(
                    rx.button("Управление медициной", variant="outline", color_scheme="blue"),
                    href="/medicine",
                ),
                rx.link(
                    rx.button("📊 Анализ приема БАДов", variant="outline", color_scheme="blue"),
                    href="/medicine-report",
                ),
                spacing="3",
                wrap="wrap",
            ),
            rx.divider(margin_y="1em"),

            rx.heading("Projects PWA - Главное меню", size="6"),
            projects_menu(),
            
            align_items="start",
            padding="2em",
            spacing="4",
            width="100%",
        ),
        max_width="900px",
    )
