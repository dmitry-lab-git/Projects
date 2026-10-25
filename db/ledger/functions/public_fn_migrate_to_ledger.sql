CREATE OR REPLACE FUNCTION public.fn_migrate_to_ledger()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    -- Вспомогательная переменная для накопления баланса
    rec RECORD;
BEGIN
    -- 1. Полная очистка для отладки
    TRUNCATE TABLE public.ledger;

    -- 2. Вставка данных с расчетом баланса и связей
    INSERT INTO public.ledger (
        tr_id, name, operation_date, sum, type_id, 
        prev_acc_tr_id, acc_balance, system_balance, check_sum, is_verified
    )
    SELECT 
        tr_id::UUID,
        transaction_name,
        operation_date,
        tr_sum,
        tr_type_id,
        -- Получаем ID предыдущей транзакции по этому же счету
        LAG(tr_id::UUID) OVER (PARTITION BY acc_id ORDER BY operation_date, code),
        -- Вычисляем накопительный баланс счета
        SUM(tr_sum * CASE 
            WHEN tr_type_id IN ('TPE-001', 'TPE-004') THEN 1 
            WHEN tr_type_id IN ('TPE-002', 'TPE-005') THEN -1 
            ELSE 0 
        END) OVER (PARTITION BY acc_id ORDER BY operation_date, code),
        -- Глобальный баланс системы (пока равен сумме всех транзакций системы)
        SUM(tr_sum * CASE 
            WHEN tr_type_id IN ('TPE-001', 'TPE-004') THEN 1 
            WHEN tr_type_id IN ('TPE-002', 'TPE-005') THEN -1 
            ELSE 0 
        END) OVER (ORDER BY operation_date, code),
        -- Генерация контрольной суммы
        md5(tr_id || tr_type_id || operation_date::text || tr_sum::text),
        TRUE
    FROM public.tx_register
    ORDER BY operation_date, code;
END;
$function$

