CREATE OR REPLACE FUNCTION reports.run_report(p_code character varying, p_start_date date, p_end_date date)
 RETURNS TABLE(group_name text, cat_name text, total_sum numeric)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_sql text;
BEGIN
    -- Получаем текст запроса из таблицы
    SELECT sql_query INTO v_sql 
    FROM reports.report_definitions 
    WHERE report_code = p_code;

    -- Выполняем запрос, подставляя параметры
    -- Используем USING для безопасной передачи параметров
    RETURN QUERY EXECUTE v_sql 
    USING p_start_date, p_end_date;
END;
$function$

