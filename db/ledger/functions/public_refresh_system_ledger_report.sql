CREATE OR REPLACE FUNCTION public.refresh_system_ledger_report()
 RETURNS TABLE(snapshot_checksum text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    new_checksum TEXT;
BEGIN
    -- 1. Обновляем расчеты в главной книге (public.ledger)
    PERFORM public.refresh_ledger(); 
    
    -- 2. Обновляем итоговый отчет (reports.account_state_report)
    PERFORM public.refresh_account_state_report();
    
    -- 3. Снимаем чексумму (контрольная сумма по состоянию отчета)
    -- ИСПРАВЛЕНО: Запрос идет в reports.account_state_report
    -- Сортировка внутри агрегата гарантирует одинаковый хэш при идентичных данных
    SELECT md5(array_agg(t ORDER BY account_id)::text) INTO new_checksum
    FROM reports.account_state_report t;
    
    -- 4. Сохраняем в таблицу истории
    -- ИСПРАВЛЕНО: История теперь в схеме reports
    INSERT INTO reports.account_report_history (checksum, report_date)
    VALUES (new_checksum, now());
    
    RETURN QUERY SELECT new_checksum;
END;
$function$

