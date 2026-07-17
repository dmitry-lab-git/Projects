# receipts_processor/__init__.py
from dotenv import load_dotenv
import os

load_dotenv('/home/fujitsu-u745/Projects/secure_folder/receipts_processor/.env')

# Регистрация запросов (как мы уже сделали)
from core.db_utils.db_access import QueryRegistry
from receipts_processor.db_utils.db_queries import QUERIES
QueryRegistry.register(QUERIES)