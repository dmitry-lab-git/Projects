CREATE OR REPLACE FUNCTION public.safe_json_to_jsonb(p_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
    cleaned_text text;
BEGIN
    IF p_text IS NULL OR p_text = '' THEN
        RETURN NULL;
    END IF;

    -- Извлекаем текст от первой скобки до последней (срезает Markdown бэктики)
    cleaned_text := substring(p_text from '(?s)[\{\[].*[\}\]]');
    -- Очищаем от невидимых управляющих символов
    cleaned_text := regexp_replace(cleaned_text, '[\x00-\x1F\x7F]', '', 'g');
    
    RETURN cleaned_text::jsonb;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$function$

