#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
from PIL import Image, ImageOps

# Импортируем настройки холста и путей из config.py
import config

def process_image(image_path, output_path):
    try:
        print(f"⏳ Форматирование и расширение канваса: {os.path.basename(image_path)}...")
        
        # 1. Открываем изображение
        with Image.open(image_path) as img:
            img = img.convert("RGB")
            orig_w, orig_h = img.size
            
            # 2. Вычисляем стандартный отступ на основе максимальной стороны кадра
            max_dimension = max(orig_w, orig_h)
            padding = int(max_dimension * config.PADDING_PERCENT)
            
            # 3. Расширяем холст с добавлением подложки из конфига
            new_canvas = ImageOps.expand(img, border=padding, fill=config.BACKGROUND_COLOR)
            
            # 4. Сохраняем в sRGB JPEG высокого качества
            new_canvas.save(output_path, "JPEG", quality=config.JPEG_QUALITY)
            
        print(f"✅ Результат сохранен в: {os.path.relpath(output_path, config.BASE_DIR)}")
        
    except Exception as e:
        print(f"❌ Ошибка при обработке {image_path}: {e}")

def main():
    # Создаем директории, если они не существуют
    if not os.path.exists(config.OUTPUT_DIR):
        os.makedirs(config.OUTPUT_DIR)
        
    if not os.path.exists(config.INPUT_DIR):
        os.makedirs(config.INPUT_DIR)
        print(f"ℹ️ Папка {config.INPUT_DIR} была создана. Поместите туда изображения.")
        return

    # Фильтруем файлы по расширениям из конфига
    files = [f for f in os.listdir(config.INPUT_DIR) if f.lower().endswith(config.VALID_EXTENSIONS)]
    
    if not files:
        print(f"ℹ️ В папке {config.INPUT_DIR} нет файлов для обработки.")
        return

    for filename in files:
        in_path = os.path.join(config.INPUT_DIR, filename)
        out_name = os.path.splitext(filename)[0] + "_processed.jpg"
        out_path = os.path.join(config.OUTPUT_DIR, out_name)
        
        process_image(in_path, out_path)

if __name__ == "__main__":
    main()
