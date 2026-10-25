CREATE OR REPLACE FUNCTION public.refresh_ledger()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    ALTER TABLE public.ledger DISABLE TRIGGER ALL;
    TRUNCATE TABLE public.ledger;

    INSERT INTO public.ledger (
        transaction_id, transaction_uuid, name, operation_date, category_id, 
        amount, type_id, contragent_from_id, contragent_to_id, account_id,
        acc_balance, system_balance, prev_acc_tr_id, prev_acc_tr_balance, check_sum
    )
    WITH base_data AS (
        SELECT 
            tr.code, tr.id, tr.transaction_name, tr.operation_date,
            cat.category_id, tr.amount, 
            t.type_id as tpe_label,
            t.account_effect,
            cf.contragent_id as cf_id, 
            ct.contragent_id as ct_id, 
            acc.account_id as acc_code,
            tr.account_id as acc_uuid
        FROM public.transactions tr
        LEFT JOIN dicts.dict_categories cat ON tr.category_id = cat.id
        LEFT JOIN dicts.dict_types t ON tr.type_id = t.id
        LEFT JOIN dicts.contragents cf ON tr.contragent_from_id = cf.id
        LEFT JOIN dicts.contragents ct ON tr.contragent_to_id = ct.id
        LEFT JOIN dicts.accounts acc ON tr.account_id = acc.id
    ),
    acc_running AS (
        -- Шаг 1: Считаем баланс счета
        SELECT *,
            SUM(amount * account_effect) OVER (PARTITION BY acc_uuid ORDER BY code) as running_acc_balance
        FROM base_data
    ),
    final_calc AS (
        -- Шаг 2: Берем LAG от уже посчитанного баланса
        SELECT *,
            LAG(code) OVER (PARTITION BY acc_uuid ORDER BY code) as prev_id,
            LAG(running_acc_balance) OVER (PARTITION BY acc_uuid ORDER BY code) as prev_bal
        FROM acc_running
    )
    SELECT 
        code, id, transaction_name, operation_date, category_id, 
        amount, tpe_label, cf_id, ct_id, acc_code,
        running_acc_balance,
        SUM(amount * account_effect) OVER (ORDER BY code),
        prev_id,
        COALESCE(prev_bal, 0),
        'CALCULATED'
    FROM final_calc
    ORDER BY code ASC;

    ALTER TABLE public.ledger ENABLE TRIGGER ALL;
EXCEPTION
    WHEN OTHERS THEN
        ALTER TABLE public.ledger ENABLE TRIGGER ALL;
        RAISE;
END;
$function$

