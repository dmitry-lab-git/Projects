import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/ledger_db")
SOURCE_DOCS_PATH = "/home/fujitsu-u745/Projects/Ledger/raw_data_ipad/docs"