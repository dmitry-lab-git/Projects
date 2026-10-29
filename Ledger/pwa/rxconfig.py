import reflex as rx
import os
from dotenv import load_dotenv

load_dotenv("/home/fujitsu-u745/Projects/secure_folder/pwa/.env")

config = rx.Config(
    app_name="pwa",
    api_url="http://192.168.43.218:8000",
    backend_host="0.0.0.0",
    frontend_host="0.0.0.0",
    backend_port=8000,
    frontend_port=3000,
    plugins=[
        rx.plugins.RadixThemesPlugin(),
        rx.plugins.SitemapPlugin(),
    ],
    db_url=os.getenv("DATABASE_URL"),
)