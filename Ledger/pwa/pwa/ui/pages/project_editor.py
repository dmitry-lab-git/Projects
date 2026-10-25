import reflex as rx
from pwa.state.projects import ProjectsState

@rx.page(route="/projects/editor", on_load=ProjectsState.load_projects_data)
def project_editor_page() -> rx.Component:
    return rx.container(
        rx.vstack(
            rx.hstack(
                rx.link("← К реестру проектов", href="/projects"),
                rx.spacer(),
                rx.link("На главную →", href="/"),
                width="100%",
            ),
            rx.heading("Редактор проектов", size="7"),
            rx.text("Управление атрибутами проектов, системными статусами и JSONB метаданными.", color_scheme="gray"),
            
            # Смарт-поиск (растянут на всю ширину над таблицей)
            rx.input(
                rx.input.slot(rx.icon("search", size=18)),
                placeholder="Поиск по названию, UUID, slug или домену...",
                value=ProjectsState.search_query,
                on_change=ProjectsState.set_search_query,
                debounce=300,
                size="3",
                width="100%",
            ),
            
            # Таблица проектов
            rx.scroll_area(
                rx.table.root(
                    rx.table.header(
                        rx.table.row(
                            rx.table.column_header_cell("Slug / ID"),
                            rx.table.column_header_cell("Название проекта"),
                            rx.table.column_header_cell("Домен"),
                            rx.table.column_header_cell("Статус"),
                            rx.table.column_header_cell("Действия"),
                        ),
                    ),
                    rx.table.body(
                        rx.cond(
                            ProjectsState.filtered_projects.length() > 0,
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
                                        rx.hstack(
                                            rx.button(
                                                rx.icon("pencil", size=16),
                                                "Редактировать",
                                                size="2",
                                                variant="soft",
                                                on_click=lambda: ProjectsState.open_edit_modal(item),
                                            ),
                                            spacing="2",
                                        ),
                                        white_space="nowrap",
                                    ),
                                ),
                            ),
                            rx.table.row(
                                rx.table.cell(
                                    rx.text("Загрузка данных или ничего не найдено...", color_scheme="gray", size="2"),
                                    col_span=5,
                                    align="center",
                                )
                            ),
                        ),
                    ),
                    width="100%",
                ),
                max_height="600px",
                width="100%",
            ),

            # Модальное окно просмотра деталей (метаданных)
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

            # Модальное окно редактирования
            rx.dialog.root(
                rx.dialog.content(
                    rx.dialog.title("Редактирование проекта"),
                    rx.dialog.description("Измените поля проекта, статус или JSONB метаданные."),
                    rx.vstack(
                        rx.cond(
                            ProjectsState.edit_error_message != "",
                            rx.callout(
                                ProjectsState.edit_error_message,
                                icon="triangle_alert",
                                color_scheme="red",
                                size="1",
                                width="100%",
                            ),
                            rx.fragment(),
                        ),
                        rx.vstack(
                            rx.text("Slug", size="2", weight="bold"),
                            rx.input(
                                value=ProjectsState.edit_slug,
                                on_change=ProjectsState.set_edit_slug,
                                width="100%",
                            ),
                            spacing="1",
                            width="100%",
                        ),
                        rx.vstack(
                            rx.text("Название (Title)", size="2", weight="bold"),
                            rx.input(
                                value=ProjectsState.edit_title,
                                on_change=ProjectsState.set_edit_title,
                                width="100%",
                            ),
                            spacing="1",
                            width="100%",
                        ),
                        rx.vstack(
                            rx.text("Статус проекта", size="2", weight="bold"),
                            rx.select(
                                ProjectsState.available_statuses_dict,
                                value=ProjectsState.edit_status_id,
                                on_change=ProjectsState.set_edit_status_id,
                                width="100%",
                            ),
                            spacing="1",
                            width="100%",
                        ),
                        rx.vstack(
                            rx.text("Метаданные (JSONB)", size="2", weight="bold"),
                            rx.text_area(
                                value=ProjectsState.edit_meta_json,
                                on_change=ProjectsState.set_edit_meta_json,
                                height="150px",
                                width="100%",
                            ),
                            spacing="1",
                            width="100%",
                        ),
                        spacing="3",
                        width="100%",
                        margin_y="1em",
                    ),
                    rx.flex(
                        rx.dialog.close(
                            rx.button(
                                "Отмена",
                                variant="soft",
                                color_scheme="gray",
                                on_click=ProjectsState.close_edit_modal,
                            ),
                        ),
                        rx.button(
                            "Сохранить",
                            on_click=ProjectsState.update_project,
                            color_scheme="blue",
                        ),
                        spacing="3",
                        justify="end",
                    ),
                    max_width="600px",
                ),
                open=ProjectsState.is_edit_modal_open,
            ),

            spacing="4",
            padding_top="2em",
        ),
        size="4",
    )