import reflex as rx
import os
from dotenv import load_dotenv
from reflex.plugins.sitemap import SitemapPlugin
from reflex_components_radix.plugin import RadixThemesPlugin
from reflex_base.plugins.sitemap import SitemapPlugin

# Загружаем переменные из .env
load_dotenv("/home/fujitsu-u745/Projects/secure_folder/pwa/.env")

config = rx.Config(
    app_name="pwa",
    plugins=[
        rx.plugins.RadixThemesPlugin(),
    ],
    disable_plugins=[SitemapPlugin],  # Передаем класс, а не строку
    db_url=os.getenv("DATABASE_URL"),
)