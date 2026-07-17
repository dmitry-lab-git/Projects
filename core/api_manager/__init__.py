# api_manager/__init__.py

from core.db_utils.db_access import QueryRegistry
from api_manager.db_utils.db_queries import QUERIES
from api_manager.service import secure_api_call

QueryRegistry.register(QUERIES)

