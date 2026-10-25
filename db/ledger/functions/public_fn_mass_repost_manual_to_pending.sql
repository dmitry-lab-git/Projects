CREATE OR REPLACE FUNCTION public.fn_mass_repost_manual_to_pending()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_count INTEGER := 0;
    r RECORD;
BEGIN
    -- Проходим циклом по всем записям с нужным статусом
    FOR r IN 
        SELECT id FROM public.tx_pending_manual_confirmation 
        WHERE status = 'need_correction'
    LOOP
        -- Используем уже написанную нами функцию для каждой записи
        PERFORM public.fn_repost_manual_to_pending(r.id);
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$function$

