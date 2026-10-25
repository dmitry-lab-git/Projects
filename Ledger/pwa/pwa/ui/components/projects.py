import reflex as rx
from pwa.state.projects import ProjectsState

def projects_component() -> rx.Component:
    return rx.vstack(
        # 1. Панель фильтров и группировки
        rx.card(
            rx.vstack(
                rx.heading("Фильтры проектов", size="4"),
                # Смарт-поиск сверху фильтров
                rx.input(
                    rx.input.slot(rx.icon("search", size=18)),
                    placeholder="Поиск по названию, UUID, slug или домену...",
                    value=ProjectsState.search_query,
                    on_change=ProjectsState.set_search_query,
                    debounce=300,
                    size="3",
                    width="100%",
                ),
                rx.hstack(
                    rx.vstack(
                        rx.text("Домен", size="2", weight="bold"),
                        rx.select(
                            ProjectsState.available_domains,
                            value=ProjectsState.selected_domain,
                            on_change=ProjectsState.set_filter_domain,
                            width="200px",
                        ),
                        spacing="1",
                    ),
                    rx.vstack(
                        rx.text("Статус", size="2", weight="bold"),
                        rx.select(
                            ProjectsState.available_statuses,
                            value=ProjectsState.selected_status,
                            on_change=ProjectsState.set_filter_status,
                            width="200px",
                        ),
                        spacing="1",
                    ),
                    spacing="4",
                    wrap="wrap",
                    width="100%",
                ),
                spacing="3",
            ),
            width="100%",
        ),
        rx.divider(margin_y="1em"),

        # 2. Таблица проектов
        rx.scroll_area(
            rx.table.root(
                rx.table.header(
                    rx.table.row(
                        rx.table.column_header_cell("ID / Slug"),
                        rx.table.column_header_cell("Название проекта"),
                        rx.table.column_header_cell("Домен"),
                        rx.table.column_header_cell("Статус"),
                        rx.table.column_header_cell("Метаданные"),
                    ),
                ),
                rx.table.body(
                    rx.foreach(
                        ProjectsState.filtered_projects,
                        lambda item: rx.table.row(
                            rx.table.cell(
                                rx.vstack(
                                    rx.text(item["slug"], weight="bold", size="2"),
                                    rx.text(
                                        rx.cond(item["id"] != "", item["id"][:8] + "...", ""),
                                        size="1",
                                        color_scheme="gray",
                                    ),
                                    spacing="1",
                                ),
                                white_space="nowrap",
                            ),
                            rx.table.cell(
                                rx.text(item["title"], size="2"),
                            ),
                            rx.table.cell(
                                rx.badge(item["domain"], variant="soft", color_scheme="blue"),
                                white_space="nowrap",
                            ),
                            rx.table.cell(
                                rx.badge(item["status_name"], variant="surface", color_scheme="green"),
                                white_space="nowrap",
                            ),
                            rx.table.cell(
                                rx.button(
                                    rx.icon("eye", size=14),
                                    "Параметры",
                                    size="1",
                                    variant="soft",
                                    color_scheme="gray",
                                    on_click=lambda: ProjectsState.open_detail_modal(item),
                                ),
                                white_space="nowrap",
                            ),
                        ),
                    ),
                ),
                width="100%",
            ),
            max_height="500px",
            width="100%",
        ),

        # 3. Модальное окно просмотра деталей (метаданных)
        rx.dialog.root(
            rx.dialog.content(
                rx.dialog.title(rx.text("Детали проекта: ", ProjectsState.detail_project_title)),
                rx.dialog.description("Полный список параметров и метаданных проекта."),
                rx.vstack(
                    rx.scroll_area(
                        rx.table.root(
                            rx.table.header(
                                rx.table.row(
                                    rx.table.column_header_cell("Ключ (Parameter)"),
                                    rx.table.column_header_cell("Значение (Value)"),
                                ),
                            ),
                            rx.table.body(
                                rx.foreach(
                                    ProjectsState.detail_project_meta_items,
                                    lambda entry: rx.table.row(
                                        rx.table.cell(rx.text(entry["key"], weight="bold", size="2")),
                                        rx.table.cell(rx.text(entry["value"], size="2")),
                                    ),
                                ),
                            ),
                            width="100%",
                        ),
                        max_height="350px",
                        width="100%",
                    ),
                    spacing="3",
                    width="100%",
                    margin_y="1em",
                ),
                rx.flex(
                    rx.dialog.close(
                        rx.button(
                            "Закрыть",
                            variant="soft",
                            color_scheme="gray",
                            on_click=ProjectsState.close_detail_modal,
                        ),
                    ),
                    justify="end",
                ),
                max_width="600px",
            ),
            open=ProjectsState.is_detail_modal_open,
        ),

        spacing="4",
        width="100%",
    )