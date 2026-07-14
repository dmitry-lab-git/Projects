from pathlib import Path
import os

from dotenv import load_dotenv
from openai import OpenAI

# Загружаем .env из secure_folder
env_path = Path.home() / "Projects/secure_folder/openai/.env"
load_dotenv(env_path)

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

models = client.models.list()

print("Доступные модели:")
for model in sorted(models.data, key=lambda m: m.id):
    print(f" - {model.id}")