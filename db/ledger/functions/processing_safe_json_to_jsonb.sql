CREATE OR REPLACE FUNCTION processing.safe_json_to_jsonb(p_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
    RETURN p_text::jsonb;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$function$

