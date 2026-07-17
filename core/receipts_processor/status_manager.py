from core.db_utils.db_access import db_fetch_val

class StatusRegistry:
    def __init__(self, conn):
        self._conn = conn
        self._cache = {}
        self._load_all()

    def _load_all(self):
        # Определение всех статусов для предзагрузки
        status_definitions = [
            ('source_files', 'UNREADABLE'), ('source_files', 'READY_TO_SEND'), 
            ('source_files', 'FINISHED'), ('source_files', 'REJECTED'),
            ('source_files', 'PROCESSING'), ('source_files', 'API_ERROR'),
            ('source_files', 'NEEDS_REVIEW'), ('source_files', 'SPLITED'),
            ('receipts', 'NO_TRANSACTION_FOUND'), ('receipts', 'LINKED'),
            ('receipts', 'INSUFFICIENT_DATA'), ('receipts', 'UNREADABLE'),
            ('receipts', 'REJECTED')
        ]
        
        for table, status in status_definitions:
            sid = db_fetch_val(self._conn, "GET_STATUS_ID", (status, table))
            if sid is None:
                raise ValueError(f"Статус {status} для таблицы {table} не найден в БД!")
            self._cache[f"{table}.{status}"] = sid

    def get(self, table, status):
        key = f"{table}.{status}"
        if key not in self._cache:
            raise ValueError(f"Статус {key} не зарегистрирован в StatusRegistry")
        return self._cache[key]
