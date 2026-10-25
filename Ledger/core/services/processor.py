import easyocr
import os

# Инициализируем ридер. 
# gpu=False принудительно говорит библиотеке использовать только CPU
reader = easyocr.Reader(['ru', 'en'], gpu=False)

def process_receipt(file_path):
    print(f"--- Обработка файла: {file_path} ---")
    # Распознавание текста
    result = reader.readtext(file_path, detail=0)
    
    # Выводим результат
    print("Найденный текст:")
    for line in result:
        print(f" > {line}")

if __name__ == "__main__":
    # Укажите путь к любому одному JPG файлу для теста
    test_file = "/home/fujitsu-u745/Projects/Ledger/raw_data_ipad/docs/IMG_0744.JPG"
    
    if os.path.exists(test_file):
        process_receipt(test_file)
    else:
        print(f"Файл {test_file} не найден. Проверьте путь.")