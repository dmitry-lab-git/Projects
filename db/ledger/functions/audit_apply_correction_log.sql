CREATE OR REPLACE PROCEDURE audit.apply_correction_log(IN p_correction_id uuid)
 LANGUAGE plpgsql
AS $procedure$
/*
  СУТЬ РАБОТЫ ФУНКЦИИ:
  1. Функция извлекает данные для корректировки из таблицы audit.transactions_corrections.
  2. Использует динамический SQL для обновления целевого поля в public.transactions.
  3. В случае успеха:
     - Устанавливает статус 'applied'.
     - Проставляет флаг is_applied = true.
     - Фиксирует время применения (applied_at).
     - Добавляет примечание об успехе.
  4. В случае ошибки:
     - Устанавливает статус 'rejected'.
     - Записывает текст ошибки в поле applying_note для отладки.
*/
DECLARE
    v_tx_id uuid;
    v_field text;
    v_value text;
    v_status text;
BEGIN
    -- Получение параметров правки из JSON-контракта
    SELECT transaction_id, (correction_json->>'target_field'), (correction_json->>'new_value'), status
    INTO v_tx_id, v_field, v_value, v_status
    FROM audit.transactions_corrections 
    WHERE id = p_correction_id;

    -- Применяем правку, только если запись имеет статус 'ready'
    IF v_status = 'ready' THEN
        -- Выполнение обновления целевого поля
        EXECUTE format('UPDATE public.transactions SET %I = $1 WHERE id = $2', v_field)
        USING v_value, v_tx_id;

        -- Фиксация успеха: статус, время, флаг и примечание
        UPDATE audit.transactions_corrections 
        SET status = 'applied', 
            is_applied = true,
            applied_at = CURRENT_TIMESTAMP,
            applying_note = 'Правка успешно применена через динамический SQL'
        WHERE id = p_correction_id;
    END IF;

EXCEPTION WHEN OTHERS THEN
    -- Логирование ошибки при сбое транзакции
    UPDATE audit.transactions_corrections 
    SET status = 'rejected', 
        applying_note = 'Ошибка применения: ' || SQLERRM 
    WHERE id = p_correction_id;
    
    -- Вывод сообщения в консоль для мониторинга
    RAISE NOTICE 'Ошибка обработки ID %: %', p_correction_id, SQLERRM;
END;
$procedure$

