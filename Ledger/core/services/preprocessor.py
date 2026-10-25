import cv2
import numpy as np

class ReceiptPreprocessor:
    @staticmethod
    def load_and_binarize(image_path):
        img = cv2.imread(image_path)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        # Адаптивный порог для выделения текста
        binary = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
            cv2.THRESH_BINARY, 11, 2
        )
        return binary

    @staticmethod
    def segment_receipts(image):
        """
        Здесь будет логика поиска контуров (чеков) на листе.
        Пока вернем список из двух сегментов (как заглушку для вашей задачи).
        """
        h, w = image.shape
        # Пример: делим изображение пополам
        # В будущем здесь будет поиск прямоугольных контуров через cv2.findContours
        return [image[0:h//2, :], image[h//2:h, :]]