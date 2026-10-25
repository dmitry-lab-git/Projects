import reflex as rx
from pwa.db import engine as ledger_engine        # Подключение к БД ledger (из словарей)
from pwa.db import household_engine               # Подключение к БД household (из медицины)
from sqlalchemy import text
from pydantic import BaseModel
import json

class StatusItem(BaseModel):
    id: str = ""
    name: str = ""

class ProjectItem(BaseModel):
    id: str = ""
    slug: str = ""
    title: str = ""
    status_id: str = ""
    status_name: str = ""
    domain: str = ""
    meta_json: str = "{}"

class ProjectsState(rx.State):
    # Сырые объединенные данные проектов из двух БД
    all_projects: list[ProjectItem] = []
    
    # Справочник статусов для селектов (чистый список строк для rx.select)
    available_statuses_dict: list[str] = []

    # Списки уникальных значений для фильтров (вычисляются динамически)
    available_domains: list[str] = []
    available_statuses: list[str] = []
    
    # Выбранные пользователем фильтры
    selected_domain: str = "Все"
    selected_status: str = "Все"
    
    # Поисковый запрос для смарт-поиска
    search_query: str = ""
    
    # Флаг группировки: "status", "domain" или "none"
    group_by_field: str = "none"

    # Состояние для модального окна редактирования
    is_edit_modal_open: bool = False
    edit_project_id: str = ""
    edit_slug: str = ""
    edit_title: str = ""
    edit_status_id: str = ""
    edit_meta_json: str = "{}"
    edit_error_message: str = ""

    # Состояние для модального окна подробного просмотра метаданных
    is_detail_modal_open: bool = False
    detail_project_title: str = ""
    detail_project_meta_items: list[dict] = []

    @rx.event
    def load_projects_data(self):
        """Загрузка данных из двух независимых БД и их слияние"""
        try:
            # 0. Загрузка справочника статусов из dicts.dict_statuses (только для entity_type = 'PROJECT')
            with ledger_engine.connect() as conn:
                statuses_query = text("""
                    SELECT id, name FROM dicts.dict_statuses
                    WHERE entity_type = 'PROJECT'
                    ORDER BY name
                """)
                status_rows = conn.execute(statuses_query).fetchall()
                # Сохраняем названия статусов для rx.select
                self.available_statuses_dict = [str(row.name) for row in status_rows]
                # 1. Запрос к БД ledger (Таблица реестра проектов и статусы)
                ledger_query = text("""
                    SELECT
                        r.id,
                        r.slug,
                        r.status_id,
                        COALESCE(s.name, r.status_id::text) as status_name
                    FROM projects.registry r
                    LEFT JOIN dicts.dict_statuses s ON r.status_id = s.id
                    ORDER BY r.created_at DESC
                """)
                ledger_rows = conn.execute(ledger_query).fetchall()
                
                ledger_data = {
                    str(row.id): {
                        "id": str(row.id),
                        "slug": row.slug,
                        "status_id": str(row.status_id) if row.status_id else "",
                        "status_name": row.status_name
                    }
                    for row in ledger_rows
                }

            # 2. Запрос к БД household (Таблица метаданных с JSONB)
            with household_engine.connect() as conn:
                household_query = text("""
                    SELECT project_id, title, meta 
                    FROM projects.metadata
                """)
                household_rows = conn.execute(household_query).fetchall()
                
                household_data = {
                    str(row.project_id): {
                        "title": row.title,
                        "meta": row.meta if isinstance(row.meta, dict) else json.loads(row.meta or '{}')
                    }
                    for row in household_rows
                }

            # 3. Слияние данных (In-Memory Join на бэкенде)
            merged_list = []
            domains_set = set()
            statuses_set = set()
            
            for p_id, l_info in ledger_data.items():
                h_info = household_data.get(p_id, {"title": l_info["slug"], "meta": {}})
                
                meta_obj = h_info["meta"]
                domain = meta_obj.get("domain", meta_obj.get("category", "unknown"))
                
                if "category" in meta_obj and meta_obj["category"] == "Photo Production":
                    domain = "Photo Production"
                    
                status_name = l_info["status_name"]
                
                project_item = ProjectItem(
                    id=p_id,
                    slug=l_info["slug"],
                    title=h_info["title"],
                    status_id=l_info["status_id"],
                    status_name=status_name,
                    domain=str(domain),
                    meta_json=json.dumps(meta_obj, ensure_ascii=False, indent=2)
                )
                
                merged_list.append(project_item)
                domains_set.add(str(domain))
                statuses_set.add(status_name)

            self.all_projects = merged_list
            self.available_domains = ["Все"] + sorted(list(domains_set))
            self.available_statuses = ["Все"] + sorted(list(statuses_set))
        except Exception as e:
            print(f"Error loading projects data: {e}")
            self.all_projects = []
            self.available_domains = ["Все"]
            self.available_statuses = ["Все"]

    @rx.event
    def open_edit_modal(self, item: dict):
        """Открытие модального окна редактирования проекта"""
        self.edit_project_id = item.get("id", "")
        self.edit_slug = item.get("slug", "")
        self.edit_title = item.get("title", "")
        # Устанавливаем текущее название статуса, чтобы оно соответствовало значениям в available_statuses_dict
        self.edit_status_id = item.get("status_name", "")
        self.edit_meta_json = item.get("meta_json", "{}")
        self.edit_error_message = ""
        self.is_edit_modal_open = True

    @rx.event
    def close_edit_modal(self):
        """Закрытие модального окна"""
        self.is_edit_modal_open = False
        self.edit_error_message = ""

    @rx.event
    def open_detail_modal(self, item: dict):
        """Открытие модального окна подробного просмотра метаданных"""
        self.detail_project_title = item.get("title", "Проект")
        meta_json_str = item.get("meta_json", "{}")
        try:
            meta_dict = json.loads(meta_json_str)
            if not isinstance(meta_dict, dict):
                meta_dict = {"raw": meta_json_str}
        except Exception:
            meta_dict = {"raw": meta_json_str}

        self.detail_project_meta_items = [
            {"key": str(k), "value": str(v)} for k, v in meta_dict.items()
        ]
        self.is_detail_modal_open = True

    @rx.event
    def close_detail_modal(self):
        """Закрытие модального окна подробностей"""
        self.is_detail_modal_open = False
        self.detail_project_meta_items = []

    @rx.event
    def set_edit_slug(self, val: str):
        self.edit_slug = val
    @rx.event
    def set_edit_title(self, val: str):
        self.edit_title = val

    @rx.event
    def set_edit_status_id(self, val: str):
        self.edit_status_id = val

    @rx.event
    def set_edit_meta_json(self, val: str):
        self.edit_meta_json = val

    @rx.event
    def set_search_query(self, val: str):
        """Установка поискового запроса для смарт-поиска с debounce (300мс)"""
        self.search_query = val

    @rx.event
    def update_project(self):
        """Транзакционное сохранение изменений проекта в обеих БД"""
        try:
            try:
                parsed_meta = json.loads(self.edit_meta_json)
            except json.JSONDecodeError as err:
                self.edit_error_message = f"Ошибка JSON в метаданных: {err}"
                return

            # Находим ID выбранного статуса по его названию в available_statuses_dict / dict_statuses
            status_id_val = None
            if self.edit_status_id and self.edit_status_id != "":
                with ledger_engine.connect() as conn:
                    status_res = conn.execute(
                        text("SELECT id FROM dicts.dict_statuses WHERE name = :name AND entity_type = 'PROJECT'"),
                        {"name": self.edit_status_id}
                    ).fetchone()
                    if status_res:
                        status_id_val = str(status_res.id)

            # 1. Обновление в БД ledger (projects.registry)
            with ledger_engine.begin() as conn:
                    conn.execute(
                        text("""
                        UPDATE projects.registry
                        SET slug = :slug, status_id = :status_id
                        WHERE id = :id
                        """),
                        {
                        "slug": self.edit_slug,
                        "status_id": status_id_val,
                        "id": self.edit_project_id
                        }
                    )

            # 2. Обновление в БД household (projects.metadata) с передачей словаря или json-строки
            with household_engine.begin() as conn:
                check_res = conn.execute(
                    text("SELECT 1 FROM projects.metadata WHERE project_id = :project_id"),
                    {"project_id": self.edit_project_id}
                ).fetchone()

                if check_res:
                    conn.execute(
                        text("""
                            UPDATE projects.metadata
                            SET title = :title, meta = CAST(:meta AS jsonb)
                            WHERE project_id = :project_id
                        """),
                        {
                            "title": self.edit_title,
                            "meta": json.dumps(parsed_meta),
                            "project_id": self.edit_project_id
                        }
                    )
                else:
                    conn.execute(
                        text("""
                            INSERT INTO projects.metadata (project_id, title, meta)
                            VALUES (:project_id, :title, CAST(:meta AS jsonb))
                        """),
                        {
                            "project_id": self.edit_project_id,
                            "title": self.edit_title,
                            "meta": json.dumps(parsed_meta)
                        }
                    )

            self.is_edit_modal_open = False
            self.edit_error_message = ""
            return ProjectsState.load_projects_data()
        except Exception as e:
            print(f"Error updating project: {e}")
            self.edit_error_message = f"Ошибка сохранения: {str(e)}"

    @rx.var
    def filtered_projects(self) -> list[ProjectItem]:
        """Фильтрация проектов по фильтрам и смарт-поиску (Название, Slug, UUID, Домен)"""
        result = self.all_projects
        
        if self.selected_domain != "Все":
            result = [p for p in result if p.domain == self.selected_domain]

        if self.selected_status != "Все":
            result = [p for p in result if p.status_name == self.selected_status]

        if self.search_query and self.search_query.strip() != "":
            q = self.search_query.strip().lower()
            result = [
                p for p in result
                if q in p.title.lower() 
                or q in p.slug.lower() 
                or q in p.id.lower() 
                or q in p.domain.lower()
            ]

        return result

    @rx.var
    def grouped_projects(self) -> list[dict]:
        """
        Возвращает структуру для отображения списков с группировкой.
        Если группировка отключена ("none"), оборачивает весь массив в одну дефолтную группу.
        """
        data = self.filtered_projects
        if self.group_by_field == "none":
            return [{"group_title": f"Все проекты ({len(data)})", "items": data}]

        groups = {}
        field_key = "status_name" if self.group_by_field == "status" else "domain"

        for item in data:
            val = getattr(item, field_key, "Не определено")
            if val not in groups:
                groups[val] = []
            groups[val].append(item)

        return [
            {"group_title": f"{k} ({len(v)})", "items": v}
            for k, v in sorted(groups.items())
        ]

    @rx.event
    def set_filter_domain(self, val: str):
        self.selected_domain = val

    @rx.event
    def set_filter_status(self, val: str):
        self.selected_status = val

    @rx.event
    def change_grouping(self, val: str):
        self.group_by_field = val