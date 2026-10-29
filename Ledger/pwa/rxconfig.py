
import reflex as rx
import os
from dotenv import load_dotenv
from reflex.plugins.sitemap import SitemapPlugin

load_dotenv("/home/fujitsu-u745/Projects/secure_folder/pwa/.env")

config = rx.Config(
    app_name="pwa",
    api_url="rx.constants.API_URL",
    backend_host="0.0.0.0",
    frontend_host="0.0.0.0",
    backend_port=8000,
    frontend_port=3000,
    plugins=[
        rx.plugins.RadixThemesPlugin(),
        SitemapPlugin(),
    ],
    db_url=os.getenv("DATABASE_URL"),
)