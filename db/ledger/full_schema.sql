--
-- PostgreSQL database dump
--

\restrict RGPAFSFjSZSutQGgmSf8TbGxV2UQo7MPc2GCoK6Uvp5WjTpiKsVFzD6AL1kIFie

-- Dumped from database version 18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)
-- Dumped by pg_dump version 18.6 (Ubuntu 18.6-0ubuntu0.26.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: archive; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA archive;


--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA audit;


--
-- Name: development; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA development;


--
-- Name: dicts; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA dicts;


--
-- Name: kernel; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA kernel;


--
-- Name: processing; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA processing;


--
-- Name: projects; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA projects;


--
-- Name: reports; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reports;


--
-- Name: staging; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA staging;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: make_mass_backup(); Type: FUNCTION; Schema: archive; Owner: -
--

CREATE FUNCTION archive.make_mass_backup() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Таблицы из схемы dicts
    dicts_tables text[] := ARRAY['accounts', 'addresses', 'contragents', 'dict_categories', 'dict_ledger_versions', 'dict_statuses', 'dict_types', 'entities', 'responsibles'];
    -- Таблицы из схемы public
    public_tables text[] := ARRAY['acc_balance_snapshot_register', 'ledger', 'transactions', 'trigger_control'];
    
    t_name text;
    current_suffix text;
    backup_query text;
BEGIN
    -- Формируем суффикс даты и времени, например: _20260629_210500
    current_suffix := to_char(NOW(), '_YYYYMMDD_HH24MISS');

    -- 1. Копируем таблицы из схемы dicts
    FOREACH t_name IN ARRAY dicts_tables LOOP
        backup_query := format('CREATE TABLE archive.%I AS SELECT * FROM dicts.%I;', t_name || current_suffix, t_name);
        EXECUTE backup_query;
    END LOOP;

    -- 2. Копируем таблицы из схемы public
    FOREACH t_name IN ARRAY public_tables LOOP
        backup_query := format('CREATE TABLE archive.%I AS SELECT * FROM public.%I;', t_name || current_suffix, t_name);
        EXECUTE backup_query;
    END LOOP;

    -- Возвращаем текстовый результат работы
    RETURN 'Бэкап успешно создан с суффиксом ' || current_suffix;
END;
$$;


--
-- Name: apply_correction_log(uuid); Type: PROCEDURE; Schema: audit; Owner: -
--

CREATE PROCEDURE audit.apply_correction_log(IN p_correction_id uuid)
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- Name: post_reviewed_transactions(); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION audit.post_reviewed_transactions() RETURNS TABLE(processed_count integer, status_message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    inserted_rows INT := 0;
    error_msg TEXT;
    v_state TEXT;
    v_status_reviewed_id UUID;
    v_status_posted_id UUID;
    v_status_error_id UUID;
BEGIN
    -- Получаем UUID статусов из справочника dicts.dict_statuses с учетом entity_type = 'TRANSACTION'
    SELECT id INTO v_status_reviewed_id FROM dicts.dict_statuses WHERE entity_type = 'TRANSACTION' AND code = 'REVIEWED' LIMIT 1;
    SELECT id INTO v_status_posted_id   FROM dicts.dict_statuses WHERE entity_type = 'TRANSACTION' AND code = 'POSTED' LIMIT 1;
    SELECT id INTO v_status_error_id    FROM dicts.dict_statuses WHERE entity_type = 'TRANSACTION' AND code = 'IMPORT_ERROR' LIMIT 1;

    -- 1. Перенос данных из staging в целевую таблицу transactions
    WITH inserted_data AS (
        INSERT INTO public.transactions (
            id, code, parent_id, transaction_name, amount, currency_id,
            operation_date, operation_time, registration_date, type_id,
            entity_id, category_id, responsible_id, contragent_from_id,
            contragent_to_id, account_id, source_extraction_id, tx_hash,
            status_id, created_at
        )
        SELECT 
            s.id,
            COALESCE(s.code, 0),
            NULL AS parent_id,
            s.transaction_name,
            s.amount,
            s.currency_id,
            s.operation_date,
            s.operation_time,
            COALESCE(s.registration_date, CURRENT_DATE),
            s.type_id,         
            s.entity_id,       
            s.category_id,   
            s.responsible_id, 
            s.contragent_from_id, 
            s.contragent_to_id,   
            s.account_id,    
            s.source_extraction_id,
            NULL AS tx_hash,
            COALESCE(v_status_posted_id, s.status_id) AS status_id,
            COALESCE(s.created_at, CURRENT_TIMESTAMP)
        FROM audit.staging_transactions s
        WHERE s.status_id = v_status_reviewed_id
        RETURNING id
    )
    SELECT COUNT(*) INTO inserted_rows FROM inserted_data;

    -- 2. Если вставка успешна, обновляем статус в staging на 'POSTED'
    IF inserted_rows > 0 THEN
        UPDATE audit.staging_transactions
        SET status_id = v_status_posted_id
        WHERE status_id = v_status_reviewed_id
          AND id IN (SELECT id FROM public.transactions);
    END IF;

    RETURN QUERY SELECT inserted_rows, 'Импорт успешно завершен'::TEXT;

EXCEPTION WHEN OTHERS THEN
    error_msg := SQLERRM;
    v_state := SQLSTATE;

    -- Проставляем статус ошибки для записей, которые не удалось импортировать
    BEGIN
        UPDATE audit.staging_transactions
        SET status_id = v_status_error_id
        WHERE status_id = v_status_reviewed_id;
    EXCEPTION WHEN OTHERS THEN
        -- Игнорируем вложенные ошибки
    END;

    RAISE EXCEPTION 'Сбой post_reviewed_transactions [SQLSTATE %]: %', v_state, error_msg;
END;
$$;


--
-- Name: sync_fullfields(uuid); Type: PROCEDURE; Schema: audit; Owner: -
--

CREATE PROCEDURE audit.sync_fullfields(IN p_tx_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO audit.transactions_fullfields (
        transaction_id, transaction_name, entity_id, category_id,
        amount, operation_date, code, acc_balance, last_audited_at
    )
    SELECT 
        t.id, t.transaction_name, t.entity_id, t.category_id,
        t.amount, t.operation_date, t.code, l.acc_balance, CURRENT_TIMESTAMP
    FROM public.transactions t
    -- JOIN теперь идет строго по UUID
    LEFT JOIN public.ledger l ON t.id = l.transaction_uuid 
    WHERE t.id = p_tx_id
    ON CONFLICT (transaction_id) 
    DO UPDATE SET
        transaction_name = EXCLUDED.transaction_name,
        acc_balance      = EXCLUDED.acc_balance,
        last_audited_at  = CURRENT_TIMESTAMP;
END;
$$;


--
-- Name: sync_transactions_to_fullfields(); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION audit.sync_transactions_to_fullfields() RETURNS TABLE(sync_report text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    rows_inserted bigint;
    start_time timestamp;
BEGIN
    start_time := clock_timestamp();

    -- 1. Удаляем триггер (если он был пересоздан или остался)
    DROP TRIGGER IF EXISTS trg_refresh_system_after_change ON audit.transactions_fullfields;

    -- 2. Очистка
    TRUNCATE TABLE audit.transactions_fullfields, audit.audit_process_queue CASCADE;

    -- 3. Наполнение (используем LEFT для защиты от ошибки длины)
    INSERT INTO audit.transactions_fullfields (
        transaction_id, transaction_name, entity_id, entity_name, 
        category_id, category_name, contragent_from_id, contragent_from_name, 
        contragent_to_id, contragent_to_name, account_id, account_name, 
        type_id, type_name, amount, tr_currency, operation_date, 
        code, acc_balance, prev_acc_tr_balance, prev_acc_tr_id, 
        transaction_code, audit_status
    )
    SELECT 
        t.id, LEFT(t.transaction_name, 512), e.entity_id, LEFT(e.entity_name, 100), 
        cat.category_id, LEFT(cat.category_name, 255), cf.contragent_id, LEFT(cf.contragent_name, 100), 
        ct.contragent_id, LEFT(ct.contragent_name, 100), a.account_id, LEFT(a.account_name, 100), 
        dt.type_id, LEFT(dt.type_name, 50), t.amount, cur.code, t.operation_date, 
        t.code, l.acc_balance, l.prev_acc_tr_balance, l.prev_acc_tr_id, 
        t.code, 'pending'
    FROM public.transactions t
    LEFT JOIN dicts.entities e ON t.entity_id = e.id
    LEFT JOIN dicts.dict_categories cat ON t.category_id = cat.id
    LEFT JOIN dicts.contragents cf ON t.contragent_from_id = cf.id
    LEFT JOIN dicts.contragents ct ON t.contragent_to_id = ct.id
    LEFT JOIN dicts.accounts a ON t.account_id = a.id
    LEFT JOIN dicts.dict_types dt ON t.type_id = dt.id
    LEFT JOIN dicts.dicts_currencies cur ON t.currency_id = cur.id
    LEFT JOIN public.ledger l ON t.id = l.transaction_uuid;

    GET DIAGNOSTICS rows_inserted = ROW_COUNT;

    -- 4. Наполнение очереди
    INSERT INTO audit.audit_process_queue (transaction_id, audit_status, transaction_code)
    SELECT transaction_id, 'pending', transaction_code 
    FROM audit.transactions_fullfields;

    -- 5. Формирование отчета
    sync_report := format('Sync completed. Rows processed: %s. Duration: %s.', 
                          rows_inserted, 
                          age(clock_timestamp(), start_time));
    RETURN NEXT;
END;
$$;


--
-- Name: trg_refresh_system_after_change(); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION audit.trg_refresh_system_after_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- ПРОВЕРКА: Если триггер выключен в пульте — выходим
    IF NOT public.is_trigger_active('trg_refresh_system_after_change') THEN
        RETURN NEW;
    END IF;

    -- Защита от бесконечной рекурсии
    IF (pg_trigger_depth() > 0) THEN
        RETURN NEW;
    END IF;

    -- Логика обновления
    PERFORM public.refresh_ledger();
    PERFORM public.refresh_system_ledger_report();
    
    CALL audit.sync_fullfields(NEW.id);
    
    RETURN NEW;
END;
$$;


--
-- Name: fn_auto_generate_uvr(); Type: FUNCTION; Schema: development; Owner: -
--

CREATE FUNCTION development.fn_auto_generate_uvr() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если код не передан, берем следующий из последовательности
    IF NEW.code IS NULL THEN
        NEW.code := nextval('development.version_updates_code_seq');
    END IF;

    -- Автоматически генерируем update_version_id (например, UVR-039, UVR-040), если он пустой
    IF NEW.update_version_id IS NULL OR NEW.update_version_id = '' THEN
        NEW.update_version_id := 'UVR-' || LPAD(NEW.code::text, 3, '0');
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: set_default_status(); Type: FUNCTION; Schema: dicts; Owner: -
--

CREATE FUNCTION dicts.set_default_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если status_id не был передан вручную, ищем ID для статуса 'ACTIVE'
    IF NEW.status_id IS NULL THEN
        SELECT id INTO NEW.status_id 
        FROM dicts.dict_statuses 
        WHERE entity_type = TG_TABLE_NAME 
          AND code = 'ACTIVE' 
        LIMIT 1;
    END IF;
    
    -- Возвращаем обновленную запись для вставки
    RETURN NEW;
END;
$$;


--
-- Name: fn_validate_request_log(); Type: FUNCTION; Schema: processing; Owner: -
--

CREATE FUNCTION processing.fn_validate_request_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    status_code TEXT;
BEGIN
    SELECT code INTO status_code FROM dicts.dict_statuses WHERE id = NEW.status_id;

    -- Защита от несуществующего статуса
    IF status_code IS NULL THEN
        RAISE EXCEPTION 'Неизвестный статус ID: %', NEW.status_id;
    END IF;

    -- Валидация (используем имена полей из api_requests_log)
    IF status_code IN ('PENDING', 'SENT') THEN
        IF COALESCE(NEW.input_tokens, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус % требует input_tokens > 0', status_code;
        END IF;

    ELSIF status_code = 'FINISHED' THEN
        IF COALESCE(NEW.input_tokens, 0) <= 0 OR COALESCE(NEW.output_tokens, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус FINISHED требует input и output > 0';
        END IF;
        -- Примечание: в текущем DDL api_requests_log нет поля response_received_at, 
        -- поэтому проверку для него убираем, чтобы не падало с ошибкой.

    ELSIF status_code IN ('ERROR_GENERIC', 'ERROR_QUOTA', 'ERROR_RETRY') THEN 
        IF COALESCE(NEW.output_tokens, 0) != 0 THEN 
            RAISE EXCEPTION 'Для системных ошибок (%) выходные токены должны быть 0', status_code; 
        END IF;

    ELSIF status_code IN ('TIMEOUT', 'ERROR_SAFETY', 'ABANDONED') THEN 
        IF COALESCE(NEW.input_tokens, 0) <= 0 THEN 
            RAISE EXCEPTION 'Статус % требует input_tokens > 0', status_code; 
        END IF;
        IF COALESCE(NEW.output_tokens, 0) != 0 THEN 
            RAISE EXCEPTION 'Для статуса % output_tokens должен быть 0', status_code; 
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: safe_json_to_jsonb(text); Type: FUNCTION; Schema: processing; Owner: -
--

CREATE FUNCTION processing.safe_json_to_jsonb(p_text text) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
    RETURN p_text::jsonb;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$;


--
-- Name: check_aive_lock(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_aive_lock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'Ledger is read-only. Use refresh_ledger() to update data.';
END;
$$;


--
-- Name: check_ledger_expenses_integrity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_ledger_expenses_integrity() RETURNS TABLE(value_in_ledger numeric, value_in_source numeric, global_checksum_diff numeric, is_integrity_valid boolean, audit_message text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH ledger_final_state AS (
        -- 1. Извлекаем финальную точку сквозного накопительного итога из витрины
        SELECT cat_exp_tr_cum_sum AS ledger_final_sum
        FROM public.ledger
        ORDER BY tr_id DESC
        LIMIT 1
    ),
    source_raw_state AS (
        -- 2. Считаем сумму и явно приводим её к типу NUMERIC(15, 4), чтобы убрать ошибку 42804
        SELECT SUM(-COALESCE(tx.tr_sum, 0))::NUMERIC(15, 4) AS source_final_sum
        FROM public.tx_register tx
        WHERE tx.tr_type_id IN ('TPE-002', 'TPE-005')
    )
    SELECT 
        COALESCE(l.ledger_final_sum, 0.0000)::NUMERIC(15, 4) AS value_in_ledger,
        COALESCE(s.source_final_sum, 0.0000)::NUMERIC(15, 4) AS value_in_source,
        -- Расчет отклонения с гарантией соответствия типов
        (COALESCE(l.ledger_final_sum, 0.0000) - COALESCE(s.source_final_sum, 0.0000))::NUMERIC(15, 4) AS global_checksum_diff,
        -- Флаг успешности прохождения теста
        CASE 
            WHEN (COALESCE(l.ledger_final_sum, 0.0000) - COALESCE(s.source_final_sum, 0.0000)) = 0 THEN TRUE
            ELSE FALSE
        END AS is_integrity_valid,
        -- Человекочитаемое сообщение для системного лога или оператора
        CASE 
            WHEN (COALESCE(l.ledger_final_sum, 0.0000) - COALESCE(s.source_final_sum, 0.0000)) = 0 
                THEN 'УСПЕШНО: Сквозной накопительный итог расходов полностью совпадает с первоисточником. Разница равна нулю.'
            ELSE 'КРИТИЧЕСКАЯ ОШИБКА: Обнаружено расхождение между витриной и первичными данными. Требуется аудит цепочки транзакций.'
        END AS audit_message
    FROM source_raw_state s
    LEFT JOIN ledger_final_state l ON TRUE;
END;
$$;


--
-- Name: FUNCTION check_ledger_expenses_integrity(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.check_ledger_expenses_integrity() IS 'Системная функция сквозного аудита целостности накопительного итога по контуру расходов (TPE-002, TPE-005)';


--
-- Name: fn_extract_ai_to_manual(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_extract_ai_to_manual() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO public.tx_pending_manual_confirmation (
        source_extraction_id, transaction_name, operation_date, operation_time,
        category_id, category_name, entity_id, entity_name,
        contragent_from_id, contragent_from_name, contragent_to_id, contragent_to_name,
        account_id, account_name, type_id, type_name,
        amount, tr_currency, ai_conclusion, sort_order
    )
    SELECT 
        src.tx_validation_id,
        (src.ai_verdict_json->>'transaction_name'),
        (src.ai_verdict_json->>'operation_date')::date,
        (src.ai_verdict_json->>'operation_time')::time,
        COALESCE(src.ai_verdict_json->>'category_id', 'needreview'),
        (SELECT category_name FROM public.dict_categories WHERE category_id = src.ai_verdict_json->>'category_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'entity_id', 'needreview'),
        (SELECT entity_name FROM public.entities WHERE entity_id = src.ai_verdict_json->>'entity_id' LIMIT 1),
        (src.ai_verdict_json->>'contragent_from_id'),
        (SELECT contragent_name FROM public.contragents WHERE cnaid = src.ai_verdict_json->>'contragent_from_id' LIMIT 1),
        (src.ai_verdict_json->>'contragent_to_id'),
        (SELECT contragent_name FROM public.contragents WHERE cnaid = src.ai_verdict_json->>'contragent_to_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'account_id', 'needreview'),
        (SELECT account_name FROM public.accounts WHERE account_id = src.ai_verdict_json->>'account_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'type_id', 'needreview'),
        (SELECT type_name FROM public.dict_types WHERE type_id = src.ai_verdict_json->>'type_id' LIMIT 1),
        COALESCE(src.ai_verdict_json->>'amount', 'nodata'),
        COALESCE(src.ai_verdict_json->>'tr_currency', 'KZT'),
        (src.ai_verdict_json->>'conclusion'),
        ROW_NUMBER() OVER (ORDER BY (src.ai_verdict_json->>'operation_date')::date ASC, 
                           COALESCE((src.ai_verdict_json->>'operation_time')::time, '00:00:00') ASC)
    FROM public.tx_pending_validation src
    WHERE src.status = 'PENDING';

    UPDATE public.tx_pending_validation SET status = 'PROCESSED' WHERE status = 'PENDING';
END;
$$;


--
-- Name: fn_general_update_limiter(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_general_update_limiter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- ПРИНУДИТЕЛЬНЫЙ ВЫХОД, если в таблице стоит FALSE
    IF NOT public.is_trigger_active('trg_lock_transactions') THEN
        RETURN NEW;
    END IF;

    -- Если триггер активен, тогда и только тогда проверяем сессию
    IF current_setting('app.allow_maintenance', true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION 'Обновление заблокировано. Для выполнения операции установите SET app.allow_maintenance = ''true'';';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_is_trigger_enabled(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_is_trigger_enabled(t_name text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
    SELECT COALESCE((SELECT is_enabled FROM public.trigger_control WHERE trigger_name = t_name), TRUE);
$$;


--
-- Name: fn_mass_repost_manual_to_pending(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_mass_repost_manual_to_pending() RETURNS integer
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fn_migrate_staging_to_transactions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_migrate_staging_to_transactions() RETURNS TABLE(out_code integer, out_transaction_id character varying, out_amount numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    WITH inserted_rows AS (
        INSERT INTO public.transactions (
            code,
            transaction_id,
            transaction_name,
            entity_id,
            registration_date,
            operation_date,
            category_id,
            responsible_id,
            contragent_from_id,
            contragent_to_id,
            account_id,
            type_id,
            amount,
            tr_currency,
            id,
            operation_time,
            source_extraction_id
        )
        SELECT 
            st.code,
            'TRS-' || st.code::text,
            st.transaction_name,
            st.entity_id,
            st.registration_date,
            st.operation_date,
            st.category_id,
            st.responsible_id,
            st.contragent_from_id,
            st.contragent_to_id,
            st.account_id,
            st.type_id,
            st.amount,
            st.tr_currency,
            st.id,
            st.operation_time,
            st.source_extraction_id
        FROM development.staging_transactions st
        WHERE st.status = 'ready_to_post'
        RETURNING code, transaction_id, amount
    )
    SELECT * FROM inserted_rows;

    -- Обновляем статус только для тех, что были успешно вставлены
    UPDATE development.staging_transactions 
    SET status = 'posted' 
    WHERE status = 'ready_to_post';
END;
$$;


--
-- Name: fn_migrate_to_ledger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_migrate_to_ledger() RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: fn_protect_core_ledger_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_protect_core_ledger_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка состояния триггера в таблице управления
    IF NOT public.is_trigger_active('trg_protect_verified_data') THEN
        RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
    END IF;

    -- Защита исторического контура (code <= 1821)
    IF (TG_OP = 'UPDATE' AND OLD.code <= 1821) THEN
        IF (OLD.code IS DISTINCT FROM NEW.code) OR
           (OLD.legacy_code IS DISTINCT FROM NEW.legacy_code) OR
           (OLD.tr_sum IS DISTINCT FROM NEW.tr_sum) OR
           (OLD.acc_id IS DISTINCT FROM NEW.acc_id) OR
           (OLD.tr_type_id IS DISTINCT FROM NEW.tr_type_id) OR
           (OLD.operation_date IS DISTINCT FROM NEW.operation_date) OR
           (OLD.registration_date IS DISTINCT FROM NEW.registration_date) THEN
            
            RAISE EXCEPTION 'Критическая ошибка: Попытка изменения неизменяемого компонента ядра (code: %) в защищенном контуре.', OLD.code;
        END IF;
    END IF;

    -- Блокировка удаления
    IF (TG_OP = 'DELETE' AND OLD.code <= 1821) THEN
        RAISE EXCEPTION 'Критическая ошибка: Удаление записей из исторического контура (code: %) запрещено.', OLD.code;
    END IF;

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: fn_protect_migrated_transactions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_protect_migrated_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, входит ли изменяемый/удаляемый код в какой-либо закрытый интервал миграции
    IF EXISTS (
        SELECT 1 
        FROM public.sys_migration_log 
        WHERE (TG_OP = 'DELETE' AND OLD.code BETWEEN tx_code_start AND tx_code_end)
           OR (TG_OP = 'UPDATE' AND OLD.code BETWEEN tx_code_start AND tx_code_end)
    ) THEN
        RAISE EXCEPTION 'Критическая ошибка безопасности (ABS): Изменение или удаление исторической транзакции с кодом % запрещено. Данный интервал состояний зафиксирован в sys_migration_log и неизменяем.', 
            CASE WHEN TG_OP = 'DELETE' THEN OLD.code ELSE NEW.code END;
    END IF;
    
    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;


--
-- Name: fn_repost_manual_to_pending(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_repost_manual_to_pending(target_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_source_id uuid;
    v_exists boolean;
BEGIN
    -- 1. Берем ID источника из правки
    SELECT source_extraction_id INTO v_source_id 
    FROM public.tx_pending_manual_confirmation 
    WHERE id = target_id;

    -- 2. Проверяем, существует ли он в основной таблице экстракции
    SELECT EXISTS(SELECT 1 FROM public.tme_tx_extraction WHERE id = v_source_id) 
    INTO v_exists;

    -- 3. Вставляем, используя NULL, если ссылка битая
    INSERT INTO public.tx_pending_posting (
        source_extraction_id,
        transaction_name,
        amount,
        operation_date,
        account_id,
        category_id,
        entity_id,
        tr_currency,
        status,
        review_notes
    )
    SELECT 
        CASE WHEN v_exists THEN source_extraction_id ELSE NULL END,
        transaction_name,
        CASE 
            WHEN amount = 'nodata' OR amount IS NULL THEN 0 
            ELSE amount::numeric 
        END,
        operation_date,
        account_id,
        category_id,
        entity_id,
        tr_currency,
        'pending',
        'Manual correction: ' || COALESCE(manual_notes, 'none')
    FROM public.tx_pending_manual_confirmation
    WHERE id = target_id 
      AND status = 'need_correction';

    -- 4. Отмечаем как REPOSTED
    UPDATE public.tx_pending_manual_confirmation 
    SET status = 'REPOSTED' 
    WHERE id = target_id 
      AND status = 'need_correction';
END;
$$;


--
-- Name: fn_repost_manual_to_posting(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_repost_manual_to_posting(target_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_source_id uuid;
    -- Объявляем переменные для всех полей
    v_rec RECORD;
BEGIN
    -- 1. Берем данные конкретной записи
    SELECT * INTO v_rec 
    FROM public.tx_pending_manual_confirmation 
    WHERE id = target_id 
      AND status = 'need_correction';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Запись % не найдена или статус не need_correction', target_id;
    END IF;

    -- 2. Вставляем, явно указывая source_extraction_id
    INSERT INTO public.tx_pending_posting (
        source_extraction_id,
        transaction_name,
        amount,
        operation_date,
        account_id,
        category_id,
        entity_id,
        tr_currency,
        status,
        review_notes
    ) VALUES (
        v_rec.source_extraction_id, -- Явное использование переменной
        v_rec.transaction_name,
        CASE WHEN v_rec.amount = 'nodata' OR v_rec.amount IS NULL THEN 0 ELSE v_rec.amount::numeric END,
        v_rec.operation_date,
        v_rec.account_id,
        v_rec.category_id,
        v_rec.entity_id,
        v_rec.tr_currency,
        'pending',
        'Manual correction: ' || COALESCE(v_rec.manual_notes, 'none')
    );

    -- 3. Обновляем статус
    UPDATE public.tx_pending_manual_confirmation 
    SET status = 'REPOSTED' 
    WHERE id = target_id;
END;
$$;


--
-- Name: fn_validate_request_log(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validate_request_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    status_code TEXT;
BEGIN
    -- 1. Получаем текстовый код статуса
    SELECT code INTO status_code 
    FROM dicts.dict_statuses 
    WHERE id = NEW.status_id;

    -- 2. Валидация промежуточных статусов (PENDING, SENT)
    IF status_code IN ('PENDING', 'SENT') THEN
        IF COALESCE(NEW.input_token_count, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус % требует input_token_count > 0', status_code;
        END IF;

    -- 3. Валидация успешного завершения (FINISHED)
    ELSIF status_code = 'FINISHED' THEN
        IF COALESCE(NEW.input_token_count, 0) <= 0 OR COALESCE(NEW.output_token_count, 0) <= 0 THEN
            RAISE EXCEPTION 'Статус FINISHED требует input и output > 0';
        END IF;
        IF NEW.response_received_at IS NULL THEN
            RAISE EXCEPTION 'Статус FINISHED требует заполненного response_received_at';
        END IF;

    -- 4. Валидация пред-ошибок (генерация даже не началась)
    ELSIF status_code IN ('ERROR_GENERIC', 'ERROR_QUOTA', 'ERROR_RETRY') THEN 
        IF COALESCE(NEW.input_token_count, 0) != 0 OR COALESCE(NEW.output_token_count, 0) != 0 THEN 
            RAISE EXCEPTION 'Для системных ошибок (%) токены должны быть равны 0', status_code; 
        END IF;

    -- 5. Валидация пост-ошибок (запрос ушел, но ответ не сгенерирован)
    ELSIF status_code IN ('TIMEOUT', 'ERROR_SAFETY', 'ABANDONED') THEN 
        IF COALESCE(NEW.input_token_count, 0) <= 0 THEN 
            RAISE EXCEPTION 'Статус % означает, что запрос отправлялся, требуется input_token_count > 0', status_code; 
        END IF;
        IF COALESCE(NEW.output_token_count, 0) != 0 THEN 
            RAISE EXCEPTION 'Для статуса % output_token_count должен быть равен 0', status_code; 
        END IF;
    END IF;

    -- Пропускаем корректную запись дальше
    RETURN NEW;
END;
$$;


--
-- Name: get_mass_ddl(text, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_mass_ddl(p_schema text, p_tables text[]) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    result_ddl text := '';
    rec record;
BEGIN
    FOR rec IN 
        WITH table_list AS (
            SELECT p_schema AS s_name, unnest(p_tables) AS t_name
        ),
        table_info AS (
            SELECT 
                c.oid,
                tl.s_name AS schema_name,
                tl.t_name AS table_name
            FROM table_list tl
            JOIN pg_catalog.pg_namespace n ON n.nspname = tl.s_name
            JOIN pg_catalog.pg_class c ON c.relnamespace = n.oid AND c.relname = tl.t_name
        ),
        columns AS (
            SELECT 
                ti.oid,
                string_agg(
                    '    ' || rpad(a.attname, 30) || ' ' || 
                    pg_catalog.format_type(a.atttypid, a.atttypmod) || 
                    CASE WHEN a.attnotnull THEN ' NOT NULL' ELSE '' END, 
                    E',\n' ORDER BY a.attnum
                ) AS col_lines
            FROM table_info ti
            JOIN pg_catalog.pg_attribute a ON a.attrelid = ti.oid
            WHERE a.attnum > 0 AND NOT a.attisdropped
            GROUP BY ti.oid
        ),
        constraints AS (
            SELECT 
                ti.oid,
                string_agg('ALTER TABLE ' || ti.schema_name || '.' || ti.table_name || ' ADD ' || pg_get_constraintdef(con.oid) || ';', E'\n') AS con_lines
            FROM table_info ti
            JOIN pg_catalog.pg_constraint con ON con.conrelid = ti.oid
            WHERE con.contype IN ('p', 'f', 'u', 'c') 
            GROUP BY ti.oid
        ),
        indexes AS (
            SELECT 
                ti.oid,
                string_agg(pg_get_indexdef(i.indexrelid) || ';', E'\n') AS idx_lines
            FROM table_info ti
            JOIN pg_catalog.pg_index i ON i.indrelid = ti.oid
            JOIN pg_catalog.pg_class c ON c.oid = i.indexrelid
            WHERE NOT i.indisprimary
            GROUP BY ti.oid
        )
        SELECT 
            '-- ====================================================' || E'\n' ||
            '-- TABLE: ' || ti.schema_name || '.' || ti.table_name || E'\n' ||
            '-- ====================================================' || E'\n\n' ||
            'CREATE TABLE ' || ti.schema_name || '.' || ti.table_name || E' (\n' || 
            coalesce(cols.col_lines, '') || E'\n);\n\n' ||
            coalesce(cons.con_lines, '-- Нет ограничений (PK/FK/CHECK)') || E'\n\n' ||
            coalesce(idxs.idx_lines, '-- Нет дополнительных индексов') || E'\n\n' AS table_ddl
        FROM table_info ti
        LEFT JOIN columns cols ON cols.oid = ti.oid
        LEFT JOIN constraints cons ON cons.oid = ti.oid
        LEFT JOIN indexes idxs ON idxs.oid = ti.oid
        ORDER BY ti.table_name
    LOOP
        result_ddl := result_ddl || rec.table_ddl;
    END LOOP;

    IF result_ddl = '' THEN
        RETURN '-- Указанные таблицы или схема не найдены.';
    END IF;

    RETURN result_ddl;
END;
$$;


--
-- Name: is_trigger_active(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_trigger_active(t_name text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN COALESCE(
        (SELECT is_enabled FROM public.trigger_control WHERE trigger_name = t_name), 
        TRUE
    );
END;
$$;


--
-- Name: prevent_snapshot_modification(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_snapshot_modification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        RAISE EXCEPTION 'Update on table acc_balance_snapshot_register is not allowed.';
    ELSIF (TG_OP = 'DELETE') THEN
        RAISE EXCEPTION 'Delete from table acc_balance_snapshot_register is not allowed.';
    END IF;
    
    RETURN NEW;
END;
$$;


--
-- Name: protect_existing_transactions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_existing_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        RAISE EXCEPTION 'Изменение существующих строк запрещено';
    ELSIF (TG_OP = 'DELETE') THEN
        RAISE EXCEPTION 'Удаление существующих строк запрещено';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: protect_verified_ledger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_verified_ledger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Защищаем весь проверенный исторический контур (с 1 по 1821 строки)
    IF (TG_OP = 'DELETE' AND OLD.code <= 1821) OR 
       (TG_OP = 'UPDATE' AND OLD.code <= 1821) THEN
        RAISE EXCEPTION 'Критическая ошибка: Попытка изменения защищенного исторического контура (строки 1-1821). Операция заблокирована.';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: refresh_account_state_report(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_account_state_report() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_count INTEGER;
    v_verified_count INTEGER;
    v_total_balance_sum NUMERIC(19, 4);
    v_verified_ids UUID[]; -- Массив настоящих UUID
    v_status_id UUID;
    v_verification_hash VARCHAR(64);
BEGIN
    -- 1. Очищаем старый отчет
    TRUNCATE TABLE reports.account_state_report;

    -- 2. Генерируем новый отчет и вставляем данные (здесь account_id остается кодом для отчета)
    INSERT INTO reports.account_state_report (
        account_id, 
        account_name, 
        entity, 
        balance, 
        account_balance_status, 
        last_updated, 
        account_state, 
        snapshot_tr_id, 
        acc_last_tr_id, 
        acc_balance_snapshot_balance
    )
    WITH latest_ledger AS (
        SELECT 
            account_id,
            MAX(transaction_id) as last_tr_id,
            (ARRAY_AGG(acc_balance ORDER BY transaction_id DESC))[1] as current_balance
        FROM public.ledger 
        GROUP BY account_id
    ),
    latest_snapshot AS (
        SELECT DISTINCT ON (account_id)
            account_id,
            tr_id::integer as snapshot_tr_id,
            balance::numeric as snapshot_balance
        FROM public.acc_balance_snapshot_register
        ORDER BY account_id, code DESC
    ),
    combined AS (
        SELECT 
            acc.account_id::varchar(50),
            acc.account_name,
            ent.entity_name,
            ll.current_balance,
            CASE 
                WHEN ls.snapshot_tr_id IS NULL THEN 'no_snapshot'
                WHEN ls.snapshot_tr_id < ll.last_tr_id THEN 'outdated'
                WHEN ls.snapshot_balance != ll.current_balance THEN 'balance_mismatch'
                ELSE 'verified'
            END as status,
            CURRENT_TIMESTAMP as last_updated,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM public.ledger l 
                    WHERE l.account_id = acc.account_id 
                    AND l.operation_date > CURRENT_DATE - INTERVAL '3 months'
                ) OR ll.current_balance != 0 THEN 'active'
                ELSE 'inactive'
            END as state,
            ls.snapshot_tr_id,
            ll.last_tr_id,
            ls.snapshot_balance
        FROM dicts.accounts acc
        JOIN latest_ledger ll ON acc.account_id = ll.account_id
        LEFT JOIN latest_snapshot ls ON acc.account_id = ls.account_id
        LEFT JOIN dicts.entities ent ON acc.entity_id = ent.entity_id
        WHERE (ll.current_balance != 0 OR EXISTS (SELECT 1 FROM public.ledger WHERE account_id = acc.account_id))
    )
    SELECT * FROM combined;

    -- 3. Снимаем показатели, вытаскивая оригинальные UUID счетов по их коду (account_id)
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE r.account_balance_status = 'verified'),
        COALESCE(SUM(r.balance) FILTER (WHERE r.account_balance_status = 'verified'), 0),
        -- Собираем массив реальных UUID из таблицы dicts.accounts
        ARRAY_AGG(a.id ORDER BY a.id) FILTER (WHERE r.account_balance_status = 'verified'),
        -- Хэш теперь тоже строится на основе стабильных UUID счетов и их балансов
        md5(ARRAY_TO_STRING(ARRAY_AGG(a.id::text || ':' || r.balance::text ORDER BY a.id) FILTER (WHERE r.account_balance_status = 'verified'), ','))
    INTO 
        v_total_count, 
        v_verified_count,
        v_total_balance_sum,
        v_verified_ids,
        v_verification_hash
    FROM reports.account_state_report r
    LEFT JOIN dicts.accounts a ON r.account_id = a.account_id; -- Джойнимся для получения UUID (a.id)

    -- 4. Проверяем условие на SUCCESS
    IF v_total_count > 0 AND v_total_count = v_verified_count THEN
        
        SELECT id INTO v_status_id 
        FROM dicts.dict_statuses 
        WHERE entity_type = 'SYSTEM_VERIFICATION' AND code = 'SUCCESS';

        IF v_status_id IS NULL THEN
            INSERT INTO dicts.dict_statuses (entity_type, code, name)
            VALUES ('SYSTEM_VERIFICATION', 'SUCCESS', 'Все счета верифицированы')
            RETURNING id INTO v_status_id;
        END IF;

        -- Записываем лог
        INSERT INTO reports.system_verification_log (
            status_id,
            total_accounts_processed, 
            verified_count, 
            total_balance_sum,
            verified_account_ids,
            verification_hash
        )
        VALUES (
            v_status_id,
            v_total_count, 
            v_verified_count, 
            v_total_balance_sum,
            COALESCE(v_verified_ids, '{}'::UUID[]),
            v_verification_hash
        )
        ON CONFLICT (verification_hash) DO NOTHING;
        
    END IF;

END;
$$;


--
-- Name: refresh_ledger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_ledger() RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: refresh_system_ledger_report(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_system_ledger_report() RETURNS TABLE(snapshot_checksum text)
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: safe_json_to_jsonb(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.safe_json_to_jsonb(p_text text) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
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
$$;


--
-- Name: update_receipts_contragent_by_amount(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receipts_contragent_by_amount() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    updated_count integer;
BEGIN
    WITH unique_mapping AS (
        SELECT amount, operation_date, MIN(contragent_to_id::text)::uuid AS contragent_to_id
        FROM public.transactions
        WHERE contragent_to_id IS NOT NULL
        GROUP BY amount, operation_date
        HAVING COUNT(DISTINCT contragent_to_id) = 1
    )
    UPDATE processing.receipts r
    SET contragent_id = um.contragent_to_id
    FROM unique_mapping um
    WHERE r.amount = um.amount
      AND r.operation_date = um.operation_date
      AND r.contragent_id IS NULL;
      
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;


--
-- Name: update_receipts_data(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receipts_data() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    updated_count integer;
BEGIN
    WITH unique_mapping AS (
        SELECT 
            amount, 
            operation_date, 
            MIN(account_id::text)::uuid AS account_id,
            MIN(contragent_to_id::text)::uuid AS contragent_to_id
        FROM public.transactions
        WHERE contragent_to_id IS NOT NULL
        GROUP BY amount, operation_date
        HAVING COUNT(DISTINCT contragent_to_id) = 1
           AND COUNT(DISTINCT account_id) = 1
    )
    UPDATE processing.receipts r
    SET 
        contragent_id = COALESCE(r.contragent_id, um.contragent_to_id),
        account_id = COALESCE(r.account_id, um.account_id)
    FROM unique_mapping um
    WHERE r.amount = um.amount
      AND r.operation_date = um.operation_date
      AND (r.contragent_id IS NULL OR r.account_id IS NULL);
      
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;


--
-- Name: update_receipts_from_transactions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receipts_from_transactions() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    updated_count integer;
BEGIN
    -- Собираем все ID транзакций для конкретной даты и суммы в массив
    WITH transactions_agg AS (
        SELECT 
            amount, 
            operation_date, 
            array_agg(id) AS transaction_ids
        FROM public.transactions
        WHERE contragent_to_id IS NOT NULL
        GROUP BY amount, operation_date
    )
    -- Обновляем чеки, добавляя массив транзакций
    UPDATE processing.receipts r
    SET 
        transaction_id = ta.transaction_ids
    FROM transactions_agg ta
    WHERE r.amount = ta.amount
      AND r.operation_date = ta.operation_date
      AND r.transaction_id IS NULL;
      
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;


--
-- Name: run_report(character varying, date, date); Type: FUNCTION; Schema: reports; Owner: -
--

CREATE FUNCTION reports.run_report(p_code character varying, p_start_date date, p_end_date date) RETURNS TABLE(group_name text, cat_name text, total_sum numeric)
    LANGUAGE plpgsql
    AS $$
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
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acc_balance_snapshot_register_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.acc_balance_snapshot_register_20260629_205647 (
    code integer,
    account_id character varying(50),
    tr_id character varying(50),
    balance integer,
    registration_date date,
    legacy_code integer,
    created_at timestamp with time zone,
    id uuid
);


--
-- Name: accounts_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.accounts_20260629_205647 (
    code integer,
    account_name character varying(50),
    account_id character varying(50),
    entity_id character varying(50),
    id uuid,
    opening_date date,
    keywords text,
    created_at timestamp with time zone,
    status_id uuid
);


--
-- Name: addresses_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.addresses_20260629_205647 (
    code integer,
    adress_name character varying(64),
    address_id character varying(50),
    external_status character varying(50),
    observed_at character varying(50),
    city character varying(50),
    country character varying(50),
    id uuid,
    created_at timestamp with time zone,
    status_id uuid
);


--
-- Name: contragents_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.contragents_20260629_205647 (
    code integer,
    contragent_name character varying(50),
    contragent_id character varying(50),
    contragent_type character varying(50),
    description character varying(512),
    adress_id character varying(50),
    id uuid,
    address_id uuid,
    keywords text[],
    created_at timestamp with time zone,
    status_id uuid
);


--
-- Name: dict_categories_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.dict_categories_20260629_205647 (
    code integer,
    category_name character varying(255),
    category_id character varying(50),
    parent_category_id character varying(50),
    keywords text[],
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- Name: dict_ledger_versions_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.dict_ledger_versions_20260629_205647 (
    code integer,
    version_name text,
    version_code text,
    registration_date date,
    description text,
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- Name: dict_statuses_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.dict_statuses_20260629_205647 (
    id uuid,
    entity_type character varying(50),
    code character varying(20),
    name character varying(100),
    created_at timestamp with time zone
);


--
-- Name: dict_types_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.dict_types_20260629_205647 (
    code integer,
    type_name character varying(50),
    type_id character varying(50),
    type_code character varying(50),
    net_value_effect character varying(50),
    account_effect numeric(19,4),
    needs_entity character varying(50),
    needs_project character varying(50),
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- Name: entities_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.entities_20260629_205647 (
    code integer,
    entity_name character varying(50),
    entity_id character varying(50),
    category_id character varying(50),
    keywords text[],
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- Name: ledger_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.ledger_20260629_205647 (
    transaction_id integer,
    name character varying(512),
    operation_date date,
    category_id character varying(50),
    amount numeric(19,4),
    type_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    prev_acc_tr_id integer,
    prev_acc_tr_balance numeric(19,4),
    acc_balance numeric(19,4),
    system_balance numeric(19,4),
    check_sum character varying(64),
    is_verified boolean,
    account_id character varying(50),
    manual_acc_balance numeric(19,4),
    diff numeric(19,4),
    transaction_uuid uuid
);


--
-- Name: responsibles_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.responsibles_20260629_205647 (
    code integer,
    resp_name character varying(50),
    responsible_id character varying(50),
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- Name: staging_audit_results_backup_040726_1839; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.staging_audit_results_backup_040726_1839 (
    staging_id integer,
    transaction_id uuid,
    status character varying(50),
    diff_json jsonb,
    reasoning text,
    raw_response jsonb,
    is_applied boolean,
    applied_at timestamp without time zone,
    created_at timestamp without time zone,
    code integer,
    audit_type character varying(20),
    parent_staging_id integer,
    audit_id uuid
);


--
-- Name: transactions_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.transactions_20260629_205647 (
    code integer,
    legacy_code integer,
    transaction_name character varying(512),
    entity_id character varying(50),
    registration_date date,
    operation_date date,
    transaction_id character varying(50),
    category_id character varying(50),
    responsible_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    account_id character varying(50),
    type_id character varying(50),
    amount numeric(15,2),
    tr_currency character varying(50),
    id uuid,
    parent_id uuid,
    tx_hash character varying(64),
    created_at timestamp without time zone,
    operation_time time without time zone,
    source_extraction_id uuid
);


--
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transactions_new_id_not_null NOT NULL,
    code integer CONSTRAINT transactions_new_code_not_null NOT NULL,
    parent_id uuid,
    transaction_name character varying(1024),
    amount numeric(15,2) CONSTRAINT transactions_new_amount_not_null NOT NULL,
    currency_id uuid CONSTRAINT transactions_new_currency_id_not_null NOT NULL,
    operation_date date CONSTRAINT transactions_new_operation_date_not_null NOT NULL,
    operation_time time without time zone,
    registration_date date CONSTRAINT transactions_new_registration_date_not_null NOT NULL,
    type_id uuid CONSTRAINT transactions_new_type_id_not_null NOT NULL,
    entity_id uuid CONSTRAINT transactions_new_entity_id_not_null NOT NULL,
    category_id uuid CONSTRAINT transactions_new_category_id_not_null NOT NULL,
    responsible_id uuid CONSTRAINT transactions_new_responsible_id_not_null NOT NULL,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid CONSTRAINT transactions_new_account_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT transactions_new_source_extraction_id_not_null NOT NULL,
    tx_hash character varying(64),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transactions_new_created_at_not_null NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: transactions_new_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transactions_new_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transactions_new_code_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transactions_new_code_seq OWNED BY public.transactions.code;


--
-- Name: transactions_backup_040726_0945; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.transactions_backup_040726_0945 (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transactions_new_id_not_null NOT NULL,
    code integer DEFAULT nextval('public.transactions_new_code_seq'::regclass) CONSTRAINT transactions_new_code_not_null NOT NULL,
    parent_id uuid,
    transaction_name character varying(1024),
    amount numeric(15,2) CONSTRAINT transactions_new_amount_not_null NOT NULL,
    currency_id uuid CONSTRAINT transactions_new_currency_id_not_null NOT NULL,
    operation_date date CONSTRAINT transactions_new_operation_date_not_null NOT NULL,
    operation_time time without time zone,
    registration_date date CONSTRAINT transactions_new_registration_date_not_null NOT NULL,
    type_id uuid CONSTRAINT transactions_new_type_id_not_null NOT NULL,
    entity_id uuid CONSTRAINT transactions_new_entity_id_not_null NOT NULL,
    category_id uuid CONSTRAINT transactions_new_category_id_not_null NOT NULL,
    responsible_id uuid CONSTRAINT transactions_new_responsible_id_not_null NOT NULL,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid CONSTRAINT transactions_new_account_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT transactions_new_source_extraction_id_not_null NOT NULL,
    tx_hash character varying(64),
    status character varying(50) DEFAULT 'NEED_REVIEW'::character varying CONSTRAINT transactions_new_status_not_null NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transactions_new_created_at_not_null NOT NULL
);


--
-- Name: transactions_backup_20260630_0903; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.transactions_backup_20260630_0903 (
    code integer CONSTRAINT tx_register_code_not_null1 NOT NULL,
    legacy_code integer,
    transaction_name character varying(1024),
    entity_id character varying(50),
    registration_date date,
    operation_date date,
    transaction_id character varying(50),
    category_id character varying(50),
    responsible_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    account_id character varying(50),
    type_id character varying(50),
    amount numeric(15,2),
    tr_currency character varying(50),
    id uuid DEFAULT gen_random_uuid(),
    parent_id uuid,
    tx_hash character varying(64),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    operation_time time without time zone,
    source_extraction_id uuid
);


--
-- Name: trigger_control_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.trigger_control_20260629_205647 (
    trigger_name text,
    is_enabled boolean,
    description text,
    updated_at timestamp without time zone
);


--
-- Name: audit_process_queue; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.audit_process_queue (
    process_id integer NOT NULL,
    transaction_id uuid NOT NULL,
    audit_status character varying(20) DEFAULT 'pending'::character varying,
    last_processed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    api_attempt_count integer DEFAULT 0,
    error_message text,
    transaction_code integer
);


--
-- Name: audit_process_queue_process_id_seq; Type: SEQUENCE; Schema: audit; Owner: -
--

CREATE SEQUENCE audit.audit_process_queue_process_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_process_queue_process_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: -
--

ALTER SEQUENCE audit.audit_process_queue_process_id_seq OWNED BY audit.audit_process_queue.process_id;


--
-- Name: audit_sessions; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.audit_sessions (
    iteration_type character varying(50),
    seq integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    finished_at timestamp without time zone,
    status character varying(20),
    results_description text,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: staging_audit_results; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.staging_audit_results (
    staging_id integer NOT NULL,
    transaction_id uuid NOT NULL,
    status character varying(50),
    diff_json jsonb,
    reasoning text,
    raw_response jsonb,
    is_applied boolean DEFAULT false,
    applied_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    code integer,
    audit_type character varying(20) DEFAULT 'primary'::character varying,
    parent_staging_id integer,
    audit_id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_extraction_id uuid
);


--
-- Name: staging_audit_results_staging_id_seq; Type: SEQUENCE; Schema: audit; Owner: -
--

CREATE SEQUENCE audit.staging_audit_results_staging_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staging_audit_results_staging_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: -
--

ALTER SEQUENCE audit.staging_audit_results_staging_id_seq OWNED BY audit.staging_audit_results.staging_id;


--
-- Name: staging_transactions; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.staging_transactions (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT staging_transactions_v1_1_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT staging_transactions_v1_1_source_extraction_id_not_null NOT NULL,
    status_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    transaction_name character varying(512),
    entity_id uuid,
    registration_date date,
    operation_date date,
    category_id uuid,
    responsible_id uuid,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid,
    type_id uuid,
    amount numeric(19,4),
    currency_id uuid,
    operation_time time without time zone,
    code integer
);


--
-- Name: staging_transactions_20260701_231500; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.staging_transactions_20260701_231500 (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT staging_transactions_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT staging_transactions_source_extraction_id_not_null NOT NULL,
    status_id_str character varying(20) DEFAULT 'NEW'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    transaction_name character varying(512),
    entity_id_str character varying(50),
    registration_date date,
    operation_date date,
    category_id_str character varying(50),
    responsible_id_str character varying(50),
    contragent_from_id_str character varying(50),
    contragent_to_id_str character varying(50),
    account_id_str character varying(50),
    type_id_str character varying(50),
    amount numeric(15,2),
    currency_id_str character varying(50),
    operation_time time without time zone,
    code integer
);


--
-- Name: transactions_fullfields; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.transactions_fullfields (
    transaction_id uuid NOT NULL,
    transaction_name character varying(1024),
    entity_id character varying(50),
    entity_name character varying(100),
    category_id character varying(50),
    category_name character varying(255),
    contragent_from_id character varying(50),
    contragent_from_name character varying(100),
    contragent_to_id character varying(50),
    contragent_to_name character varying(100),
    account_id character varying(50),
    account_name character varying(100),
    type_id character varying(50),
    type_name character varying(50),
    amount numeric,
    tr_currency character varying(50),
    operation_date date,
    keywords text[],
    code integer,
    last_audited_at timestamp without time zone,
    audit_status character varying(20) DEFAULT 'pending'::character varying,
    ai_comment text,
    acc_balance numeric(19,4),
    prev_acc_tr_balance numeric(19,4),
    prev_acc_tr_id integer,
    transaction_code integer
);


--
-- Name: v_audit_diff; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.v_audit_diff AS
 SELECT t.transaction_id,
    t.category_name AS old_category,
    (s.diff_json ->> 'category_name'::text) AS new_category,
    t.keywords AS old_keywords,
    (s.diff_json ->> 'keywords'::text) AS new_keywords,
    s.reasoning
   FROM (audit.transactions_fullfields t
     JOIN audit.staging_audit_results s ON ((t.transaction_id = s.transaction_id)))
  WHERE (s.is_applied = false);


--
-- Name: file_versions; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.file_versions (
    "Код" integer,
    file_name character varying(50),
    file_version_id character varying(50),
    version_id character varying(50),
    created_at character varying(50),
    archived_at character varying(50),
    previous_file_version_id character varying(50),
    description character varying(50),
    id uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: support_tickets; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.support_tickets (
    id integer NOT NULL,
    project_id character varying(50),
    ticket_reference character varying(100),
    issue_type character varying(50),
    status character varying(20),
    attachments_path character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    comment text,
    ticket_uuid uuid DEFAULT gen_random_uuid()
);


--
-- Name: support_tickets_id_seq; Type: SEQUENCE; Schema: development; Owner: -
--

CREATE SEQUENCE development.support_tickets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: support_tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: development; Owner: -
--

ALTER SEQUENCE development.support_tickets_id_seq OWNED BY development.support_tickets.id;


--
-- Name: version_updates_code_seq; Type: SEQUENCE; Schema: development; Owner: -
--

CREATE SEQUENCE development.version_updates_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: version_updates; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.version_updates (
    code integer DEFAULT nextval('development.version_updates_code_seq'::regclass),
    update_version_name character varying(50),
    update_version_id character varying(50),
    version_id character varying(50),
    registration_date date NOT NULL,
    description text,
    affected_objects text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: COLUMN version_updates.update_version_id; Type: COMMENT; Schema: development; Owner: -
--

COMMENT ON COLUMN development.version_updates.update_version_id IS 'Идентификатор конкретного обновления (напр. UVR-002)';


--
-- Name: COLUMN version_updates.version_id; Type: COMMENT; Schema: development; Owner: -
--

COMMENT ON COLUMN development.version_updates.version_id IS 'Ссылка на основную версию системы (напр. VER-003)';


--
-- Name: versions; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.versions (
    code integer,
    version_name character varying(50),
    version_id character varying(50),
    version_code character varying(50),
    registration_date character varying(50),
    description character varying(1024),
    programming_stack character varying(100),
    dev_device character varying(100),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: accounts; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.accounts (
    code integer,
    account_name character varying(50),
    account_id character varying(50),
    entity_id character varying(50),
    id uuid DEFAULT gen_random_uuid() CONSTRAINT account_register_id_not_null NOT NULL,
    opening_date date,
    keywords text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status_id uuid NOT NULL,
    currency uuid NOT NULL
);


--
-- Name: addresses; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.addresses (
    code integer NOT NULL,
    address_name character varying(64),
    address_id character varying(50),
    external_status character varying(50),
    observed_at character varying(50),
    city character varying(50),
    country character varying(50),
    id uuid DEFAULT gen_random_uuid() CONSTRAINT adress_register_id_not_null NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status_id uuid DEFAULT '1e604e11-8e44-4da3-beb2-369a0113ffdf'::uuid NOT NULL
);


--
-- Name: addresses_code_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

ALTER TABLE dicts.addresses ALTER COLUMN code ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dicts.addresses_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contragents; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.contragents (
    code integer CONSTRAINT dict_contragent_seq_not_null NOT NULL,
    contragent_name character varying(50),
    contragent_id character varying(50),
    contragent_type character varying(50),
    description character varying(512),
    id uuid DEFAULT gen_random_uuid() CONSTRAINT contragent_register_id_not_null NOT NULL,
    address_id uuid,
    keywords text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status_id uuid NOT NULL,
    merchant_id uuid,
    legal_entity_id uuid
);


--
-- Name: counterperyid_t_flw_037_3006; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.counterperyid_t_flw_037_3006 (
    "Seq" integer,
    "CounterpartyName" text,
    "CtrCode" integer,
    "CtrID" character varying(50),
    "Type" character varying(50),
    "Status" character varying(50),
    "CreatedAt" character varying(50),
    "ObservedAt" character varying(50),
    "Описание" text,
    "Адрес" character varying(64),
    "Телефон" character varying(50),
    "Комментарий" text
);


--
-- Name: dict_categories; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_categories (
    code integer CONSTRAINT dict_category_id_not_null NOT NULL,
    category_name character varying(255) CONSTRAINT dict_category_category_name_not_null NOT NULL,
    category_id character varying(50) CONSTRAINT dict_category_category_id_not_null NOT NULL,
    parent_category_id character varying(50),
    keywords text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: dict_category_id_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.dict_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dict_category_id_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.dict_category_id_seq OWNED BY dicts.dict_categories.code;


--
-- Name: dict_contragent_seq_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.dict_contragent_seq_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dict_contragent_seq_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.dict_contragent_seq_seq OWNED BY dicts.contragents.code;


--
-- Name: dict_ledger_versions; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_ledger_versions (
    code integer CONSTRAINT dict_ledger_versions_version_id_not_null NOT NULL,
    version_name text NOT NULL,
    version_code text NOT NULL,
    registration_date date CONSTRAINT dict_ledger_versions_created_at_not_null NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL,
    CONSTRAINT chk_version_desc_length CHECK ((char_length(description) > 10))
);


--
-- Name: dict_ledger_versions_version_id_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.dict_ledger_versions_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dict_ledger_versions_version_id_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.dict_ledger_versions_version_id_seq OWNED BY dicts.dict_ledger_versions.code;


--
-- Name: dict_statuses; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_statuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type character varying(50) NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: dict_types; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_types (
    code integer,
    type_name character varying(50),
    type_id character varying(50),
    net_value_effect character varying(50),
    account_effect numeric(19,4),
    needs_entity character varying(50),
    needs_project character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: dicts_currencies; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dicts_currencies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    currency_id character varying(10) CONSTRAINT dicts_currencies_code_not_null NOT NULL,
    code integer
);


--
-- Name: entities; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.entities (
    code integer NOT NULL,
    entity_name character varying(50),
    entity_id character varying(50),
    category_id character varying(50),
    keywords text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: legal_entities; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.legal_entities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code integer NOT NULL,
    legal_name character varying(255) NOT NULL,
    tax_number character varying(20) NOT NULL,
    registration_number character varying(20),
    legal_address text,
    status_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: legal_entities_code_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.legal_entities_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legal_entities_code_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.legal_entities_code_seq OWNED BY dicts.legal_entities.code;


--
-- Name: merchants; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.merchants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code integer NOT NULL,
    merchant_name character varying(100) NOT NULL,
    default_legal_entity_id uuid,
    status_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: merchants_code_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.merchants_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merchants_code_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.merchants_code_seq OWNED BY dicts.merchants.code;


--
-- Name: responsibles; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.responsibles (
    code integer,
    resp_name character varying(50),
    responsible_id character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: source_extractions; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.source_extractions (
    id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    description text
);


--
-- Name: edges; Type: TABLE; Schema: kernel; Owner: -
--

CREATE TABLE kernel.edges (
    edge_id integer NOT NULL,
    source_node_id integer NOT NULL,
    target_node_id integer NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb
);


--
-- Name: edges_edge_id_seq; Type: SEQUENCE; Schema: kernel; Owner: -
--

CREATE SEQUENCE kernel.edges_edge_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: edges_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: kernel; Owner: -
--

ALTER SEQUENCE kernel.edges_edge_id_seq OWNED BY kernel.edges.edge_id;


--
-- Name: nodes; Type: TABLE; Schema: kernel; Owner: -
--

CREATE TABLE kernel.nodes (
    node_id integer NOT NULL,
    entity_code text NOT NULL,
    entity_type text NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb
);


--
-- Name: nodes_node_id_seq; Type: SEQUENCE; Schema: kernel; Owner: -
--

CREATE SEQUENCE kernel.nodes_node_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nodes_node_id_seq; Type: SEQUENCE OWNED BY; Schema: kernel; Owner: -
--

ALTER SEQUENCE kernel.nodes_node_id_seq OWNED BY kernel.nodes.node_id;


--
-- Name: view_rules_map; Type: VIEW; Schema: kernel; Owner: -
--

CREATE VIEW kernel.view_rules_map AS
 SELECT source.entity_code AS operation,
    target.entity_code AS target_entity,
    (e.meta ->> 'check'::text) AS rule_type,
    n.entity_type AS target_type
   FROM (((kernel.edges e
     JOIN kernel.nodes source ON ((e.source_node_id = source.node_id)))
     JOIN kernel.nodes target ON ((e.target_node_id = target.node_id)))
     JOIN kernel.nodes n ON ((e.target_node_id = n.node_id)))
  ORDER BY source.entity_code;


--
-- Name: aive_lock; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.aive_lock (
    lock_id integer DEFAULT 1 NOT NULL,
    is_locked boolean DEFAULT false,
    locked_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    protected_tables text DEFAULT 'transactions, ledger, dict_categories, dict_types, entities, contragents, acc_balance_snapshot_register'::text
);


--
-- Name: api_blocked_models; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.api_blocked_models (
    model_name text NOT NULL,
    blocked_until timestamp with time zone NOT NULL
);


--
-- Name: api_request_blobs_cache; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.api_request_blobs_cache (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    request_id uuid NOT NULL,
    file_data bytea NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: api_requests_log; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.api_requests_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_id uuid NOT NULL,
    model_family text NOT NULL,
    model_version text NOT NULL,
    status_id uuid NOT NULL,
    input_tokens integer DEFAULT 0,
    output_tokens integer DEFAULT 0,
    duration_ms integer,
    prompt_text text,
    response_text text,
    error_message text,
    file_meta jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: api_requests_log_backup_120726_1339; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.api_requests_log_backup_120726_1339 (
    code integer CONSTRAINT aive_requests_log_id_not_null NOT NULL,
    source_extraction_id uuid,
    model_used text,
    request_payload text,
    response_payload text,
    error_message text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT aive_requests_log_created_at_not_null NOT NULL,
    input_token_count integer,
    output_token_count integer,
    response_received_at timestamp without time zone,
    id uuid DEFAULT gen_random_uuid() CONSTRAINT aive_requests_log_id_not_null1 NOT NULL,
    request_count integer DEFAULT 1,
    status_id uuid CONSTRAINT aive_requests_log_status_id_not_null NOT NULL,
    request_file_meta jsonb,
    CONSTRAINT chk_request_count_positive CHECK ((request_count > 0))
);


--
-- Name: api_requests_log_code_seq; Type: SEQUENCE; Schema: processing; Owner: -
--

CREATE SEQUENCE processing.api_requests_log_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_requests_log_code_seq; Type: SEQUENCE OWNED BY; Schema: processing; Owner: -
--

ALTER SEQUENCE processing.api_requests_log_code_seq OWNED BY processing.api_requests_log_backup_120726_1339.code;


--
-- Name: receipts; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.receipts (
    id uuid NOT NULL,
    code integer NOT NULL,
    source_file_id uuid NOT NULL,
    receipt_index_on_file integer NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    raw_payload jsonb,
    legal_entity_id uuid,
    amount numeric NOT NULL,
    currency_id uuid NOT NULL,
    operation_date date NOT NULL,
    operation_time time without time zone,
    description text,
    transaction_id uuid[],
    processed_at timestamp with time zone
);


--
-- Name: receipts_code_seq; Type: SEQUENCE; Schema: processing; Owner: -
--

ALTER TABLE processing.receipts ALTER COLUMN code ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME processing.receipts_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: source_extractions; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.source_extractions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    target_name character varying(100) NOT NULL
);


--
-- Name: source_files_code_seq; Type: SEQUENCE; Schema: processing; Owner: -
--

CREATE SEQUENCE processing.source_files_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_files; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.source_files (
    id uuid CONSTRAINT source_photos_id_not_null NOT NULL,
    code integer DEFAULT nextval('processing.source_files_code_seq'::regclass) CONSTRAINT source_photos_code_not_null NOT NULL,
    file_name character varying(512) CONSTRAINT source_photos_file_name_not_null NOT NULL,
    file_path text CONSTRAINT source_photos_file_path_not_null NOT NULL,
    file_size bigint,
    device_source character varying(50) DEFAULT 'iPad'::character varying,
    upload_date date DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone CONSTRAINT source_photos_created_at_not_null NOT NULL,
    status_id uuid CONSTRAINT source_photos_status_id_not_null NOT NULL,
    file_hash character varying(64),
    parent_id uuid,
    reject_reason text
);


--
-- Name: transaction_templates; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.transaction_templates (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transaction_templates_id_not_null1 NOT NULL,
    transaction_name character varying(150) CONSTRAINT transaction_templates_transaction_name_not_null1 NOT NULL,
    amount numeric(15,2),
    currency_id uuid,
    type_id uuid,
    entity_id uuid,
    category_id uuid,
    responsible_id uuid,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid,
    status_id uuid CONSTRAINT transaction_templates_status_id_not_null1 NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transaction_templates_created_at_not_null1 NOT NULL
);


--
-- Name: transaction_templates_20261023_123600; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.transaction_templates_20261023_123600 (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transaction_templates_id_not_null NOT NULL,
    transaction_name character varying(150) CONSTRAINT transaction_templates_transaction_name_not_null NOT NULL,
    amount numeric(15,2),
    currency_id_str character varying(50),
    type_id_str character varying(50),
    entity_id_str character varying(50),
    category_id_str character varying(50),
    responsible_id_str character varying(50),
    contragent_from_id_str character varying(50),
    contragent_to_id_str character varying(50),
    account_id_str character varying(50),
    status_id uuid CONSTRAINT transaction_templates_status_id_not_null NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transaction_templates_created_at_not_null NOT NULL
);


--
-- Name: vw_source_extractions_by_target; Type: VIEW; Schema: processing; Owner: -
--

CREATE VIEW processing.vw_source_extractions_by_target AS
 SELECT target_name,
    count(*) AS extractions_count
   FROM processing.source_extractions
  GROUP BY target_name
  ORDER BY (count(*)) DESC;


--
-- Name: registry; Type: TABLE; Schema: projects; Owner: -
--

CREATE TABLE projects.registry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug character varying(64) NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: acc_balance_snapshot_register; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.acc_balance_snapshot_register (
    code integer CONSTRAINT "acc_balance_snapshot_register_Код_not_null" NOT NULL,
    account_id character varying(50),
    tr_id character varying(50),
    balance integer,
    registration_date date DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid()
);


--
-- Name: chart_of_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chart_of_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_code character varying(20) NOT NULL,
    account_name character varying(500) NOT NULL,
    parent_id uuid,
    is_reconciliation boolean DEFAULT false NOT NULL,
    account_class character varying(50) NOT NULL,
    normal_balance character varying(10) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT coa_account_class_check CHECK (((account_class)::text = ANY ((ARRAY['ASSET'::character varying, 'LIABILITY'::character varying, 'EQUITY'::character varying, 'REVENUE'::character varying, 'EXPENSE'::character varying])::text[]))),
    CONSTRAINT coa_normal_balance_check CHECK (((normal_balance)::text = ANY ((ARRAY['DEBIT'::character varying, 'CREDIT'::character varying])::text[])))
);


--
-- Name: contragent_precedents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contragent_precedents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contragent_id uuid NOT NULL,
    status_id uuid NOT NULL,
    branch_type character varying(30) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_precedent_branch_type CHECK (((branch_type)::text = ANY ((ARRAY['informative'::character varying, 'workflow'::character varying])::text[])))
);


--
-- Name: ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger (
    transaction_id integer NOT NULL,
    transaction_uuid uuid NOT NULL,
    name text,
    operation_date date NOT NULL,
    category_id character varying(50),
    amount numeric(19,4) NOT NULL,
    type_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    account_id character varying(50),
    acc_balance numeric(19,4) NOT NULL,
    system_balance numeric(19,4) NOT NULL,
    prev_acc_tr_id integer,
    prev_acc_tr_balance numeric(19,4) DEFAULT 0,
    check_sum character varying(64) NOT NULL
);


--
-- Name: posting_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posting_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_name character varying(100),
    type_name character varying(100),
    account_name character varying(100),
    debit_account_id uuid NOT NULL,
    credit_account_id uuid NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.postings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transaction_id uuid NOT NULL,
    posting_date date NOT NULL,
    debit_account_id uuid NOT NULL,
    credit_account_id uuid NOT NULL,
    amount numeric(15,2) NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT postings_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: sys_migration_objects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sys_migration_objects_id_seq
    START WITH 9
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transactions_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transactions_code_seq
    START WITH 1865
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trigger_control; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trigger_control (
    trigger_name text NOT NULL,
    is_enabled boolean DEFAULT true,
    description text,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: v_ledger_duck; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ledger_duck AS
 SELECT transaction_uuid AS "UUID",
    name AS "Название",
    operation_date AS "Дата регистрации",
    amount AS "Сумма"
   FROM public.ledger
  WHERE ((name ~~* '%флис%'::text) OR (name ~~* '%флис%'::text));


--
-- Name: account_state_report; Type: TABLE; Schema: reports; Owner: -
--

CREATE TABLE reports.account_state_report (
    account_id character varying(50) CONSTRAINT "account_state_report_AccID_not_null" NOT NULL,
    account_name character varying(100),
    entity character varying(100),
    balance numeric(19,4),
    account_balance_status character varying(50),
    last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    account_state character varying(20),
    snapshot_tr_id integer,
    acc_last_tr_id integer,
    acc_balance_snapshot_balance numeric(19,4)
);


--
-- Name: ai_proxy_transactions; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.ai_proxy_transactions AS
 SELECT t.code AS tx_code,
    t.registration_date,
    t.operation_date,
    t.operation_time,
    e.entity_name,
    cat.category_name,
    dt.type_name,
        CASE
            WHEN (c_from.code IS NOT NULL) THEN ('Contragent_'::text || c_from.code)
            ELSE NULL::text
        END AS contragent_from_name,
        CASE
            WHEN (addr_from.code IS NOT NULL) THEN ('Address_'::text || addr_from.code)
            ELSE NULL::text
        END AS contragent_from_address,
        CASE
            WHEN (c_to.code IS NOT NULL) THEN ('Contragent_'::text || c_to.code)
            ELSE NULL::text
        END AS contragent_to_name,
        CASE
            WHEN (addr_to.code IS NOT NULL) THEN ('Address_'::text || addr_to.code)
            ELSE NULL::text
        END AS contragent_to_address,
    acc.account_name,
    acc_e.entity_name AS account_entity_name,
        CASE
            WHEN (t.amount > (0)::numeric) THEN 'POSITIVE'::text
            WHEN (t.amount < (0)::numeric) THEN 'NEGATIVE'::text
            ELSE NULL::text
        END AS amount_sign,
    COALESCE(st.code, 'PENDING'::character varying) AS posting_status
   FROM (((((((((((public.transactions t
     LEFT JOIN dicts.entities e ON ((t.entity_id = e.id)))
     LEFT JOIN dicts.contragents c_from ON ((t.contragent_from_id = c_from.id)))
     LEFT JOIN dicts.addresses addr_from ON ((c_from.address_id = addr_from.id)))
     LEFT JOIN dicts.contragents c_to ON ((t.contragent_to_id = c_to.id)))
     LEFT JOIN dicts.addresses addr_to ON ((c_to.address_id = addr_to.id)))
     LEFT JOIN dicts.dict_categories cat ON ((t.category_id = cat.id)))
     LEFT JOIN dicts.accounts acc ON ((t.account_id = acc.id)))
     LEFT JOIN dicts.entities acc_e ON ((((acc.entity_id)::text = (acc_e.entity_id)::text) OR ((acc.entity_id)::text = (acc_e.id)::text))))
     LEFT JOIN dicts.dict_types dt ON ((t.type_id = dt.id)))
     LEFT JOIN public.postings p ON ((t.id = p.transaction_id)))
     LEFT JOIN dicts.dict_statuses st ON ((p.status_id = st.id)))
  ORDER BY t.code;


--
-- Name: postings_detailed; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.postings_detailed AS
 SELECT t.code AS tx_code,
    p.posting_date,
    dt_acc.account_code AS debit_account_code,
    dt_acc.account_name AS debit_account_name,
    (((dt_acc.account_code)::text || ' - '::text) || (dt_acc.account_name)::text) AS debit_account,
    cr_acc.account_code AS credit_account_code,
    cr_acc.account_name AS credit_account_name,
    (((cr_acc.account_code)::text || ' - '::text) || (cr_acc.account_name)::text) AS credit_account,
    p.amount,
    st.code AS status_code,
    st.name AS status_name,
    p.created_at
   FROM ((((public.postings p
     JOIN public.transactions t ON ((p.transaction_id = t.id)))
     JOIN public.chart_of_accounts dt_acc ON ((p.debit_account_id = dt_acc.id)))
     JOIN public.chart_of_accounts cr_acc ON ((p.credit_account_id = cr_acc.id)))
     JOIN dicts.dict_statuses st ON ((p.status_id = st.id)))
  ORDER BY t.code;


--
-- Name: system_verification_log; Type: TABLE; Schema: reports; Owner: -
--

CREATE TABLE reports.system_verification_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    verified_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status_id uuid NOT NULL,
    total_accounts_processed integer NOT NULL,
    verified_count integer NOT NULL,
    total_balance_sum numeric(19,4) NOT NULL,
    verified_account_ids uuid[] NOT NULL,
    verification_hash character varying(64) NOT NULL
);


--
-- Name: transactions; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.transactions AS
 SELECT t.code,
    t.registration_date,
    t.operation_date,
    t.operation_time,
    t.created_at,
    e.entity_name,
    cat.category_name,
    c_from.contragent_name AS contragent_from_name,
    addr_from.address_name AS contragent_from_address,
    c_to.contragent_name AS contragent_to_name,
    addr_to.address_name AS contragent_to_address,
    acc.account_name,
    dt.type_name,
    t.amount
   FROM ((((((((public.transactions t
     LEFT JOIN dicts.entities e ON ((t.entity_id = e.id)))
     LEFT JOIN dicts.contragents c_from ON ((t.contragent_from_id = c_from.id)))
     LEFT JOIN dicts.addresses addr_from ON ((c_from.address_id = addr_from.id)))
     LEFT JOIN dicts.contragents c_to ON ((t.contragent_to_id = c_to.id)))
     LEFT JOIN dicts.addresses addr_to ON ((c_to.address_id = addr_to.id)))
     LEFT JOIN dicts.dict_categories cat ON ((t.category_id = cat.id)))
     LEFT JOIN dicts.accounts acc ON ((t.account_id = acc.id)))
     LEFT JOIN dicts.dict_types dt ON ((t.type_id = dt.id)))
  ORDER BY t.code DESC;


--
-- Name: trial_balance; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.trial_balance AS
 WITH account_turnovers AS (
         SELECT postings.debit_account_id AS account_id,
            postings.amount AS debit_amount,
            0.00 AS credit_amount
           FROM public.postings
        UNION ALL
         SELECT postings.credit_account_id AS account_id,
            0.00 AS debit_amount,
            postings.amount AS credit_amount
           FROM public.postings
        )
 SELECT coa.account_code,
    coa.account_name,
    coa.account_class,
    coa.normal_balance,
    sum(at.debit_amount) AS total_debit,
    sum(at.credit_amount) AS total_credit,
        CASE
            WHEN ((coa.normal_balance)::text = 'DEBIT'::text) THEN (sum(at.debit_amount) - sum(at.credit_amount))
            ELSE (sum(at.credit_amount) - sum(at.debit_amount))
        END AS net_balance
   FROM (public.chart_of_accounts coa
     JOIN account_turnovers at ON ((coa.id = at.account_id)))
  GROUP BY coa.id, coa.account_code, coa.account_name, coa.account_class, coa.normal_balance
  ORDER BY coa.account_code;


--
-- Name: v_active_account_report; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.v_active_account_report AS
 SELECT account_id,
    account_name,
    balance,
    account_balance_status,
    last_updated
   FROM reports.account_state_report
  WHERE (((account_state)::text = 'active'::text) AND (balance <> (0)::numeric))
  ORDER BY balance DESC;


--
-- Name: v_current_projects; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.v_current_projects AS
 SELECT p.id AS project_id,
    p.slug,
    s.code AS status_code,
    s.name AS status_name,
    p.created_at
   FROM (projects.registry p
     JOIN dicts.dict_statuses s ON ((p.status_id = s.id)))
  WHERE (((s.entity_type)::text = 'PROJECT'::text) AND ((s.code)::text = ANY ((ARRAY['DRAFT'::character varying, 'QUEUED'::character varying, 'DEVELOPMENT'::character varying, 'ACTIVE'::character varying])::text[])))
  ORDER BY p.created_at DESC;


--
-- Name: v_monthly_transactions_summary; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.v_monthly_transactions_summary AS
 SELECT (date_trunc('month'::text, (t.operation_date)::timestamp with time zone))::date AS report_month,
    t.entity_id,
    e.entity_name,
    t.category_id,
    cat.category_name,
    t.contragent_to_id AS contragent_id,
    c.contragent_name,
    t.account_id,
    acc.account_name,
    sum(t.amount) AS total_amount,
    count(t.id) AS trans_count
   FROM ((((public.transactions t
     LEFT JOIN dicts.entities e ON ((t.entity_id = e.id)))
     LEFT JOIN dicts.contragents c ON ((t.contragent_to_id = c.id)))
     LEFT JOIN dicts.dict_categories cat ON ((t.category_id = cat.id)))
     LEFT JOIN dicts.accounts acc ON ((t.account_id = acc.id)))
  WHERE (t.type_id = ANY (ARRAY['e9f1c16a-dde8-48f8-85d3-ae46b42cd9a8'::uuid, '7bf484c8-1a59-41d2-8ee3-f1a38a0e4125'::uuid]))
  GROUP BY ((date_trunc('month'::text, (t.operation_date)::timestamp with time zone))::date), t.entity_id, e.entity_name, t.category_id, cat.category_name, t.contragent_to_id, c.contragent_name, t.account_id, acc.account_name;


--
-- Name: v_textile_cohort_transactions; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.v_textile_cohort_transactions AS
 SELECT t.operation_date,
    t.code AS tx_code,
    c_to.contragent_name AS merchant_to,
    st.name AS status_name,
    st.code AS status_code,
    cat.category_name AS accounting_category,
    t.transaction_name AS transaction_title,
    t.amount AS amount_kzt,
    e.entity_name AS associated_entity,
    t.status_id,
    t.id AS transaction_uuid,
    t.category_id,
    t.entity_id
   FROM ((((public.transactions t
     JOIN dicts.contragents c_to ON ((t.contragent_to_id = c_to.id)))
     LEFT JOIN dicts.dict_statuses st ON ((t.status_id = st.id)))
     LEFT JOIN dicts.dict_categories cat ON ((t.category_id = cat.id)))
     LEFT JOIN dicts.entities e ON ((t.entity_id = e.id)))
  WHERE (((c_to.contragent_name)::text ~~* '%Tavi%'::text) OR ((c_to.contragent_name)::text ~~* '%Раушан%'::text) OR ((c_to.contragent_name)::text ~~* '%Лима%'::text) OR ((c_to.contragent_name)::text ~~* '%Магазин тканей%'::text) OR ((c_to.contragent_name)::text ~~* '%Магазин ткани и фурнитуры%'::text) OR ((c_to.contragent_name)::text ~~* '%Русские ткани%'::text) OR ((c_to.contragent_name)::text ~~* '%Ткани и фурнитура%'::text) OR ((c_to.contragent_name)::text ~~* '%Швейная фурнитура%'::text) OR ((c_to.contragent_name)::text ~~* '%Швейный дом%'::text));


--
-- Name: VIEW v_textile_cohort_transactions; Type: COMMENT; Schema: reports; Owner: -
--

COMMENT ON VIEW reports.v_textile_cohort_transactions IS 'Финансовый след текстильной когорты контрагентов во всех системных статусах для аудита закупок сырья';


--
-- Name: audit_process_queue process_id; Type: DEFAULT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_process_queue ALTER COLUMN process_id SET DEFAULT nextval('audit.audit_process_queue_process_id_seq'::regclass);


--
-- Name: staging_audit_results staging_id; Type: DEFAULT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_audit_results ALTER COLUMN staging_id SET DEFAULT nextval('audit.staging_audit_results_staging_id_seq'::regclass);


--
-- Name: support_tickets id; Type: DEFAULT; Schema: development; Owner: -
--

ALTER TABLE ONLY development.support_tickets ALTER COLUMN id SET DEFAULT nextval('development.support_tickets_id_seq'::regclass);


--
-- Name: contragents code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents ALTER COLUMN code SET DEFAULT nextval('dicts.dict_contragent_seq_seq'::regclass);


--
-- Name: dict_categories code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_categories ALTER COLUMN code SET DEFAULT nextval('dicts.dict_category_id_seq'::regclass);


--
-- Name: dict_ledger_versions code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_ledger_versions ALTER COLUMN code SET DEFAULT nextval('dicts.dict_ledger_versions_version_id_seq'::regclass);


--
-- Name: legal_entities code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities ALTER COLUMN code SET DEFAULT nextval('dicts.legal_entities_code_seq'::regclass);


--
-- Name: merchants code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants ALTER COLUMN code SET DEFAULT nextval('dicts.merchants_code_seq'::regclass);


--
-- Name: edges edge_id; Type: DEFAULT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges ALTER COLUMN edge_id SET DEFAULT nextval('kernel.edges_edge_id_seq'::regclass);


--
-- Name: nodes node_id; Type: DEFAULT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.nodes ALTER COLUMN node_id SET DEFAULT nextval('kernel.nodes_node_id_seq'::regclass);


--
-- Name: api_requests_log_backup_120726_1339 code; Type: DEFAULT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log_backup_120726_1339 ALTER COLUMN code SET DEFAULT nextval('processing.api_requests_log_code_seq'::regclass);


--
-- Name: transactions code; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions ALTER COLUMN code SET DEFAULT nextval('public.transactions_new_code_seq'::regclass);


--
-- Name: transactions_backup_040726_0945 transactions_backup_040726_0945_code_key; Type: CONSTRAINT; Schema: archive; Owner: -
--

ALTER TABLE ONLY archive.transactions_backup_040726_0945
    ADD CONSTRAINT transactions_backup_040726_0945_code_key UNIQUE (code);


--
-- Name: transactions_backup_040726_0945 transactions_backup_040726_0945_pkey; Type: CONSTRAINT; Schema: archive; Owner: -
--

ALTER TABLE ONLY archive.transactions_backup_040726_0945
    ADD CONSTRAINT transactions_backup_040726_0945_pkey PRIMARY KEY (id);


--
-- Name: transactions_backup_20260630_0903 tx_register_pkey; Type: CONSTRAINT; Schema: archive; Owner: -
--

ALTER TABLE ONLY archive.transactions_backup_20260630_0903
    ADD CONSTRAINT tx_register_pkey PRIMARY KEY (code);


--
-- Name: transactions_backup_20260630_0903 uq_transactions_id; Type: CONSTRAINT; Schema: archive; Owner: -
--

ALTER TABLE ONLY archive.transactions_backup_20260630_0903
    ADD CONSTRAINT uq_transactions_id UNIQUE (id);


--
-- Name: audit_process_queue audit_process_queue_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_process_queue
    ADD CONSTRAINT audit_process_queue_pkey PRIMARY KEY (process_id);


--
-- Name: staging_audit_results staging_audit_results_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_audit_results
    ADD CONSTRAINT staging_audit_results_pkey PRIMARY KEY (staging_id);


--
-- Name: staging_transactions_20260701_231500 staging_transactions_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions_20260701_231500
    ADD CONSTRAINT staging_transactions_pkey PRIMARY KEY (id);


--
-- Name: staging_transactions staging_transactions_v1_1_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions
    ADD CONSTRAINT staging_transactions_v1_1_pkey PRIMARY KEY (id);


--
-- Name: transactions_fullfields transactions_fullfields_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.transactions_fullfields
    ADD CONSTRAINT transactions_fullfields_pkey PRIMARY KEY (transaction_id);


--
-- Name: support_tickets support_tickets_pkey; Type: CONSTRAINT; Schema: development; Owner: -
--

ALTER TABLE ONLY development.support_tickets
    ADD CONSTRAINT support_tickets_pkey PRIMARY KEY (id);


--
-- Name: versions versionregistry_t_unique_id; Type: CONSTRAINT; Schema: development; Owner: -
--

ALTER TABLE ONLY development.versions
    ADD CONSTRAINT versionregistry_t_unique_id UNIQUE (version_id);


--
-- Name: accounts accounts_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.accounts
    ADD CONSTRAINT accounts_code_unique UNIQUE (code);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.addresses
    ADD CONSTRAINT addresses_code_unique UNIQUE (code);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: contragents contragents_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT contragents_code_unique UNIQUE (code);


--
-- Name: contragents contragents_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT contragents_pkey PRIMARY KEY (id);


--
-- Name: dict_categories dict_categories_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_categories
    ADD CONSTRAINT dict_categories_code_unique UNIQUE (code);


--
-- Name: dict_categories dict_categories_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_categories
    ADD CONSTRAINT dict_categories_pkey PRIMARY KEY (id);


--
-- Name: dict_ledger_versions dict_ledger_versions_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_ledger_versions
    ADD CONSTRAINT dict_ledger_versions_pkey PRIMARY KEY (id);


--
-- Name: dict_statuses dict_statuses_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_statuses
    ADD CONSTRAINT dict_statuses_pkey PRIMARY KEY (id);


--
-- Name: dict_types dict_types_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_types
    ADD CONSTRAINT dict_types_code_unique UNIQUE (code);


--
-- Name: dict_types dict_types_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_types
    ADD CONSTRAINT dict_types_pkey PRIMARY KEY (id);


--
-- Name: dicts_currencies dicts_currencies_code_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dicts_currencies
    ADD CONSTRAINT dicts_currencies_code_key UNIQUE (code);


--
-- Name: dicts_currencies dicts_currencies_id_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dicts_currencies
    ADD CONSTRAINT dicts_currencies_id_key UNIQUE (currency_id);


--
-- Name: dicts_currencies dicts_currencies_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dicts_currencies
    ADD CONSTRAINT dicts_currencies_pkey PRIMARY KEY (id);


--
-- Name: entities entities_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.entities
    ADD CONSTRAINT entities_code_unique UNIQUE (code);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: legal_entities legal_entities_code_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities
    ADD CONSTRAINT legal_entities_code_key UNIQUE (code);


--
-- Name: legal_entities legal_entities_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities
    ADD CONSTRAINT legal_entities_pkey PRIMARY KEY (id);


--
-- Name: legal_entities legal_entities_tax_number_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities
    ADD CONSTRAINT legal_entities_tax_number_key UNIQUE (tax_number);


--
-- Name: merchants merchants_code_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants
    ADD CONSTRAINT merchants_code_key UNIQUE (code);


--
-- Name: merchants merchants_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants
    ADD CONSTRAINT merchants_pkey PRIMARY KEY (id);


--
-- Name: responsibles responsibles_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.responsibles
    ADD CONSTRAINT responsibles_code_unique UNIQUE (code);


--
-- Name: responsibles responsibles_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.responsibles
    ADD CONSTRAINT responsibles_pkey PRIMARY KEY (id);


--
-- Name: source_extractions source_extractions_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.source_extractions
    ADD CONSTRAINT source_extractions_pkey PRIMARY KEY (id);


--
-- Name: edges edges_pkey; Type: CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges
    ADD CONSTRAINT edges_pkey PRIMARY KEY (edge_id);


--
-- Name: nodes nodes_entity_code_key; Type: CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.nodes
    ADD CONSTRAINT nodes_entity_code_key UNIQUE (entity_code);


--
-- Name: nodes nodes_pkey; Type: CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.nodes
    ADD CONSTRAINT nodes_pkey PRIMARY KEY (node_id);


--
-- Name: aive_lock aive_lock_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.aive_lock
    ADD CONSTRAINT aive_lock_pkey PRIMARY KEY (lock_id);


--
-- Name: api_requests_log_backup_120726_1339 aive_requests_log_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log_backup_120726_1339
    ADD CONSTRAINT aive_requests_log_pkey PRIMARY KEY (id);


--
-- Name: api_blocked_models api_blocked_models_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_blocked_models
    ADD CONSTRAINT api_blocked_models_pkey PRIMARY KEY (model_name);


--
-- Name: api_request_blobs_cache api_request_blobs_cache_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_request_blobs_cache
    ADD CONSTRAINT api_request_blobs_cache_pkey PRIMARY KEY (id);


--
-- Name: api_requests_log api_requests_log_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log
    ADD CONSTRAINT api_requests_log_pkey PRIMARY KEY (id);


--
-- Name: receipts receipts_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.receipts
    ADD CONSTRAINT receipts_pkey PRIMARY KEY (id);


--
-- Name: source_extractions source_extractions_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_extractions
    ADD CONSTRAINT source_extractions_pkey PRIMARY KEY (id);


--
-- Name: source_files source_files_code_key; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_code_key UNIQUE (code);


--
-- Name: source_files source_files_hash_key; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_hash_key UNIQUE (file_hash);


--
-- Name: source_files source_files_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_pkey PRIMARY KEY (id);


--
-- Name: transaction_templates_20261023_123600 tx_templates_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates_20261023_123600
    ADD CONSTRAINT tx_templates_pkey PRIMARY KEY (id);


--
-- Name: transaction_templates tx_templates_v11_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT tx_templates_v11_pkey PRIMARY KEY (id);


--
-- Name: registry projects_pkey; Type: CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.registry
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: registry projects_slug_unique; Type: CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.registry
    ADD CONSTRAINT projects_slug_unique UNIQUE (slug);


--
-- Name: acc_balance_snapshot_register acc_balance_snapshot_register_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acc_balance_snapshot_register
    ADD CONSTRAINT acc_balance_snapshot_register_pkey PRIMARY KEY (code);


--
-- Name: chart_of_accounts coa_account_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT coa_account_code_key UNIQUE (account_code);


--
-- Name: chart_of_accounts coa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT coa_pkey PRIMARY KEY (id);


--
-- Name: contragent_precedents contragent_precedents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contragent_precedents
    ADD CONSTRAINT contragent_precedents_pkey PRIMARY KEY (id);


--
-- Name: ledger ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_pkey PRIMARY KEY (transaction_id);


--
-- Name: transactions new_transactions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT new_transactions_code_key UNIQUE (code);


--
-- Name: transactions new_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT new_transactions_pkey PRIMARY KEY (id);


--
-- Name: posting_rules posting_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_pkey PRIMARY KEY (id);


--
-- Name: postings postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_pkey PRIMARY KEY (id);


--
-- Name: trigger_control trigger_control_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_control
    ADD CONSTRAINT trigger_control_pkey PRIMARY KEY (trigger_name);


--
-- Name: account_state_report account_state_report_pkey; Type: CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.account_state_report
    ADD CONSTRAINT account_state_report_pkey PRIMARY KEY (account_id);


--
-- Name: system_verification_log system_verification_log_pkey; Type: CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.system_verification_log
    ADD CONSTRAINT system_verification_log_pkey PRIMARY KEY (id);


--
-- Name: system_verification_log uq_verification_hash; Type: CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.system_verification_log
    ADD CONSTRAINT uq_verification_hash UNIQUE (verification_hash);


--
-- Name: idx_transactions_source_id; Type: INDEX; Schema: archive; Owner: -
--

CREATE INDEX idx_transactions_source_id ON archive.transactions_backup_20260630_0903 USING btree (source_extraction_id);


--
-- Name: idx_audit_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_status ON audit.transactions_fullfields USING btree (audit_status);


--
-- Name: idx_fullfields_code; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_fullfields_code ON audit.transactions_fullfields USING btree (transaction_code);


--
-- Name: idx_queue_code; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_queue_code ON audit.audit_process_queue USING btree (transaction_code);


--
-- Name: idx_queue_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_queue_status ON audit.audit_process_queue USING btree (audit_status);


--
-- Name: idx_staging_code; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_code ON audit.staging_audit_results USING btree (code);


--
-- Name: idx_staging_pending; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_pending ON audit.staging_audit_results USING btree (transaction_id) WHERE (is_applied = false);


--
-- Name: idx_staging_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_status ON audit.staging_transactions_20260701_231500 USING btree (status_id_str);


--
-- Name: idx_staging_v1_1_operation_time; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_v1_1_operation_time ON audit.staging_transactions USING btree (operation_date, operation_time);


--
-- Name: idx_staging_v1_1_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_v1_1_status ON audit.staging_transactions USING btree (status_id);


--
-- Name: idx_transactions_fullfields_keywords; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_transactions_fullfields_keywords ON audit.transactions_fullfields USING gin (keywords);


--
-- Name: idx_accounts_status_id; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_accounts_status_id ON dicts.accounts USING btree (status_id);


--
-- Name: idx_contragents_merchant; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_contragents_merchant ON dicts.contragents USING btree (merchant_id);


--
-- Name: idx_legal_entities_tax; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_legal_entities_tax ON dicts.legal_entities USING btree (tax_number);


--
-- Name: idx_merchants_legal_entity; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_merchants_legal_entity ON dicts.merchants USING btree (default_legal_entity_id);


--
-- Name: idx_statuses_entity_type; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_statuses_entity_type ON dicts.dict_statuses USING btree (entity_type);


--
-- Name: idx_unique_status_type_code; Type: INDEX; Schema: dicts; Owner: -
--

CREATE UNIQUE INDEX idx_unique_status_type_code ON dicts.dict_statuses USING btree (entity_type, code);


--
-- Name: idx_edges_source_node; Type: INDEX; Schema: kernel; Owner: -
--

CREATE INDEX idx_edges_source_node ON kernel.edges USING btree (source_node_id);


--
-- Name: idx_edges_target_node; Type: INDEX; Schema: kernel; Owner: -
--

CREATE INDEX idx_edges_target_node ON kernel.edges USING btree (target_node_id);


--
-- Name: idx_nodes_entity_code; Type: INDEX; Schema: kernel; Owner: -
--

CREATE INDEX idx_nodes_entity_code ON kernel.nodes USING btree (entity_code);


--
-- Name: idx_aive_requests_log_source_id; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_aive_requests_log_source_id ON processing.api_requests_log_backup_120726_1339 USING btree (source_extraction_id);


--
-- Name: idx_aive_requests_log_status_id; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_aive_requests_log_status_id ON processing.api_requests_log_backup_120726_1339 USING btree (status_id);


--
-- Name: idx_api_log_created; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_created ON processing.api_requests_log USING btree (created_at);


--
-- Name: idx_api_log_file_meta; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_file_meta ON processing.api_requests_log_backup_120726_1339 USING gin (request_file_meta);


--
-- Name: idx_api_log_meta; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_meta ON processing.api_requests_log USING gin (file_meta);


--
-- Name: idx_api_log_source_id; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_source_id ON processing.api_requests_log USING btree (source_id);


--
-- Name: idx_blobs_cache_created_at; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_blobs_cache_created_at ON processing.api_request_blobs_cache USING btree (created_at);


--
-- Name: idx_blobs_cache_request_id; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_blobs_cache_request_id ON processing.api_request_blobs_cache USING btree (request_id);


--
-- Name: idx_gin_aive_payload; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_gin_aive_payload ON processing.api_requests_log_backup_120726_1339 USING gin (public.safe_json_to_jsonb(response_payload));


--
-- Name: idx_receipts_legal; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_receipts_legal ON processing.receipts USING btree (legal_entity_id);


--
-- Name: idx_receipts_source_file; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_receipts_source_file ON processing.receipts USING btree (source_file_id);


--
-- Name: idx_source_files_hash; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_source_files_hash ON processing.source_files USING btree (file_hash);


--
-- Name: idx_source_target_name; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_source_target_name ON processing.source_extractions USING btree (target_name);


--
-- Name: idx_tx_templates_status; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_status ON processing.transaction_templates_20261023_123600 USING btree (status_id);


--
-- Name: idx_tx_templates_v11_account; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_v11_account ON processing.transaction_templates USING btree (account_id);


--
-- Name: idx_tx_templates_v11_entity; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_v11_entity ON processing.transaction_templates USING btree (entity_id);


--
-- Name: idx_tx_templates_v11_status; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_v11_status ON processing.transaction_templates USING btree (status_id);


--
-- Name: idx_coa_code_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_coa_code_lookup ON public.chart_of_accounts USING btree (account_code);


--
-- Name: idx_ledger_acc_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_acc_date ON public.ledger USING btree (account_id, operation_date);


--
-- Name: idx_ledger_tr_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_tr_uuid ON public.ledger USING btree (transaction_uuid);


--
-- Name: idx_posting_rules_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posting_rules_status_id ON public.posting_rules USING btree (status_id);


--
-- Name: idx_postings_credit_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_credit_account ON public.postings USING btree (credit_account_id);


--
-- Name: idx_postings_debit_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_debit_account ON public.postings USING btree (debit_account_id);


--
-- Name: idx_postings_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_status_id ON public.postings USING btree (status_id);


--
-- Name: idx_postings_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_transaction_id ON public.postings USING btree (transaction_id);


--
-- Name: idx_precedents_branch_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_precedents_branch_status ON public.contragent_precedents USING btree (branch_type, status_id);


--
-- Name: idx_precedents_contragent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_precedents_contragent ON public.contragent_precedents USING btree (contragent_id);


--
-- Name: idx_sys_verification_log_date; Type: INDEX; Schema: reports; Owner: -
--

CREATE INDEX idx_sys_verification_log_date ON reports.system_verification_log USING btree (verified_at);


--
-- Name: transactions_backup_20260630_0903 trg_01_core_protection; Type: TRIGGER; Schema: archive; Owner: -
--

CREATE TRIGGER trg_01_core_protection BEFORE DELETE OR UPDATE ON archive.transactions_backup_20260630_0903 FOR EACH ROW EXECUTE FUNCTION public.fn_protect_core_ledger_columns();

ALTER TABLE archive.transactions_backup_20260630_0903 DISABLE TRIGGER trg_01_core_protection;


--
-- Name: transactions_backup_20260630_0903 trg_02_general_limiter; Type: TRIGGER; Schema: archive; Owner: -
--

CREATE TRIGGER trg_02_general_limiter BEFORE UPDATE ON archive.transactions_backup_20260630_0903 FOR EACH ROW EXECUTE FUNCTION public.fn_general_update_limiter();

ALTER TABLE archive.transactions_backup_20260630_0903 DISABLE TRIGGER trg_02_general_limiter;


--
-- Name: transactions_backup_20260630_0903 trg_lock_transactions; Type: TRIGGER; Schema: archive; Owner: -
--

CREATE TRIGGER trg_lock_transactions BEFORE INSERT OR DELETE OR UPDATE ON archive.transactions_backup_20260630_0903 FOR EACH STATEMENT EXECUTE FUNCTION public.fn_general_update_limiter();

ALTER TABLE archive.transactions_backup_20260630_0903 DISABLE TRIGGER trg_lock_transactions;


--
-- Name: transactions_backup_20260630_0903 trg_protect_verified_data; Type: TRIGGER; Schema: archive; Owner: -
--

CREATE TRIGGER trg_protect_verified_data BEFORE DELETE OR UPDATE ON archive.transactions_backup_20260630_0903 FOR EACH ROW EXECUTE FUNCTION public.fn_protect_core_ledger_columns();

ALTER TABLE archive.transactions_backup_20260630_0903 DISABLE TRIGGER trg_protect_verified_data;


--
-- Name: transactions_backup_20260630_0903 trg_refresh_system_after_change; Type: TRIGGER; Schema: archive; Owner: -
--

CREATE TRIGGER trg_refresh_system_after_change AFTER INSERT OR UPDATE ON archive.transactions_backup_20260630_0903 FOR EACH ROW EXECUTE FUNCTION audit.trg_refresh_system_after_change();

ALTER TABLE archive.transactions_backup_20260630_0903 DISABLE TRIGGER trg_refresh_system_after_change;


--
-- Name: version_updates trg_version_updates_insert; Type: TRIGGER; Schema: development; Owner: -
--

CREATE TRIGGER trg_version_updates_insert BEFORE INSERT ON development.version_updates FOR EACH ROW EXECUTE FUNCTION development.fn_auto_generate_uvr();


--
-- Name: api_requests_log trg_validate_request_log; Type: TRIGGER; Schema: processing; Owner: -
--

CREATE TRIGGER trg_validate_request_log BEFORE INSERT OR UPDATE ON processing.api_requests_log FOR EACH ROW EXECUTE FUNCTION processing.fn_validate_request_log();


--
-- Name: api_requests_log_backup_120726_1339 trg_validate_request_log; Type: TRIGGER; Schema: processing; Owner: -
--

CREATE TRIGGER trg_validate_request_log BEFORE INSERT OR UPDATE ON processing.api_requests_log_backup_120726_1339 FOR EACH ROW EXECUTE FUNCTION processing.fn_validate_request_log();


--
-- Name: ledger trg_lock_ledger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lock_ledger BEFORE INSERT OR DELETE OR UPDATE ON public.ledger FOR EACH STATEMENT EXECUTE FUNCTION public.check_aive_lock();


--
-- Name: acc_balance_snapshot_register trg_prevent_snapshot_modification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_snapshot_modification BEFORE DELETE OR UPDATE ON public.acc_balance_snapshot_register FOR EACH ROW EXECUTE FUNCTION public.prevent_snapshot_modification();


--
-- Name: transactions trg_protect_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_transactions BEFORE DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.protect_existing_transactions();


--
-- Name: transactions_backup_20260630_0903 fk_tx_parent; Type: FK CONSTRAINT; Schema: archive; Owner: -
--

ALTER TABLE ONLY archive.transactions_backup_20260630_0903
    ADD CONSTRAINT fk_tx_parent FOREIGN KEY (parent_id) REFERENCES archive.transactions_backup_20260630_0903(id);


--
-- Name: staging_audit_results fk_staging_source_extraction; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_audit_results
    ADD CONSTRAINT fk_staging_source_extraction FOREIGN KEY (source_extraction_id) REFERENCES processing.source_extractions(id) ON DELETE SET NULL;


--
-- Name: staging_transactions fk_staging_v1_1_account; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions
    ADD CONSTRAINT fk_staging_v1_1_account FOREIGN KEY (account_id) REFERENCES dicts.accounts(id);


--
-- Name: staging_transactions fk_staging_v1_1_status; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions
    ADD CONSTRAINT fk_staging_v1_1_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: audit_process_queue fk_transaction; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_process_queue
    ADD CONSTRAINT fk_transaction FOREIGN KEY (transaction_id) REFERENCES audit.transactions_fullfields(transaction_id);


--
-- Name: transactions_fullfields transactions_fullfields_transaction_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.transactions_fullfields
    ADD CONSTRAINT transactions_fullfields_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: contragents contragents_merchant_id_fkey; Type: FK CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT contragents_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES dicts.merchants(id);


--
-- Name: contragents fk_contragent_legal_entity; Type: FK CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT fk_contragent_legal_entity FOREIGN KEY (legal_entity_id) REFERENCES dicts.legal_entities(id);


--
-- Name: merchants merchants_default_legal_entity_id_fkey; Type: FK CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants
    ADD CONSTRAINT merchants_default_legal_entity_id_fkey FOREIGN KEY (default_legal_entity_id) REFERENCES dicts.legal_entities(id);


--
-- Name: edges edges_source_node_id_fkey; Type: FK CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges
    ADD CONSTRAINT edges_source_node_id_fkey FOREIGN KEY (source_node_id) REFERENCES kernel.nodes(node_id) ON DELETE CASCADE;


--
-- Name: edges edges_target_node_id_fkey; Type: FK CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges
    ADD CONSTRAINT edges_target_node_id_fkey FOREIGN KEY (target_node_id) REFERENCES kernel.nodes(node_id) ON DELETE CASCADE;


--
-- Name: api_requests_log fk_api_requests_log_source; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log
    ADD CONSTRAINT fk_api_requests_log_source FOREIGN KEY (source_id) REFERENCES processing.source_extractions(id);


--
-- Name: api_requests_log fk_api_requests_log_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log
    ADD CONSTRAINT fk_api_requests_log_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: api_requests_log_backup_120726_1339 fk_request_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log_backup_120726_1339
    ADD CONSTRAINT fk_request_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: api_requests_log_backup_120726_1339 fk_requests_source; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log_backup_120726_1339
    ADD CONSTRAINT fk_requests_source FOREIGN KEY (source_extraction_id) REFERENCES processing.source_extractions(id);


--
-- Name: transaction_templates fk_tx_templates_account; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_account FOREIGN KEY (account_id) REFERENCES dicts.accounts(id);


--
-- Name: transaction_templates fk_tx_templates_category; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_category FOREIGN KEY (category_id) REFERENCES dicts.dict_categories(id);


--
-- Name: transaction_templates fk_tx_templates_contragent_from; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_contragent_from FOREIGN KEY (contragent_from_id) REFERENCES dicts.contragents(id);


--
-- Name: transaction_templates fk_tx_templates_contragent_to; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_contragent_to FOREIGN KEY (contragent_to_id) REFERENCES dicts.contragents(id);


--
-- Name: transaction_templates fk_tx_templates_currency; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_currency FOREIGN KEY (currency_id) REFERENCES dicts.dicts_currencies(id);


--
-- Name: transaction_templates fk_tx_templates_entity; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_entity FOREIGN KEY (entity_id) REFERENCES dicts.entities(id);


--
-- Name: transaction_templates fk_tx_templates_responsible; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_responsible FOREIGN KEY (responsible_id) REFERENCES dicts.responsibles(id);


--
-- Name: transaction_templates fk_tx_templates_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: transaction_templates_20261023_123600 fk_tx_templates_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates_20261023_123600
    ADD CONSTRAINT fk_tx_templates_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: transaction_templates fk_tx_templates_type; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_type FOREIGN KEY (type_id) REFERENCES dicts.dict_types(id);


--
-- Name: receipts receipts_currency_id_fkey; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.receipts
    ADD CONSTRAINT receipts_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES dicts.dicts_currencies(id);


--
-- Name: receipts receipts_legal_entity_id_fkey; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.receipts
    ADD CONSTRAINT receipts_legal_entity_id_fkey FOREIGN KEY (legal_entity_id) REFERENCES dicts.legal_entities(id);


--
-- Name: receipts receipts_source_file_id_fkey; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.receipts
    ADD CONSTRAINT receipts_source_file_id_fkey FOREIGN KEY (source_file_id) REFERENCES processing.source_files(id);


--
-- Name: source_files source_files_parent_id_fkey; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES processing.source_files(id);


--
-- Name: registry fk_projects_status; Type: FK CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.registry
    ADD CONSTRAINT fk_projects_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: chart_of_accounts fk_coa_parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT fk_coa_parent FOREIGN KEY (parent_id) REFERENCES public.chart_of_accounts(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: contragent_precedents fk_contragent_precedents_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contragent_precedents
    ADD CONSTRAINT fk_contragent_precedents_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: transactions fk_transactions_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_transactions_status_id FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: posting_rules posting_rules_credit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_credit_account_id_fkey FOREIGN KEY (credit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: posting_rules posting_rules_debit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_debit_account_id_fkey FOREIGN KEY (debit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: posting_rules posting_rules_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_status_id_fkey FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: postings postings_credit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_credit_account_id_fkey FOREIGN KEY (credit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: postings postings_debit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_debit_account_id_fkey FOREIGN KEY (debit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: postings postings_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_status_id_fkey FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: postings postings_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: system_verification_log fk_verification_log_status; Type: FK CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.system_verification_log
    ADD CONSTRAINT fk_verification_log_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA audit TO reflex_app_user;


--
-- Name: SCHEMA dicts; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA dicts TO receipt_processor_svc;
GRANT USAGE ON SCHEMA dicts TO reflex_app_user;


--
-- Name: SCHEMA processing; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA processing TO receipt_processor_svc;
GRANT USAGE ON SCHEMA processing TO reflex_app_user;


--
-- Name: SCHEMA projects; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA projects TO reflex_app_user;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT ALL ON SCHEMA public TO reflex_app_user;
GRANT USAGE ON SCHEMA public TO antigravity;


--
-- Name: SCHEMA reports; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA reports TO reflex_app_user;


--
-- Name: TABLE transactions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transactions TO antigravity;


--
-- Name: TABLE audit_process_queue; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.audit_process_queue TO reflex_app_user;


--
-- Name: SEQUENCE audit_process_queue_process_id_seq; Type: ACL; Schema: audit; Owner: -
--

GRANT ALL ON SEQUENCE audit.audit_process_queue_process_id_seq TO reflex_app_user;


--
-- Name: TABLE audit_sessions; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.audit_sessions TO reflex_app_user;


--
-- Name: TABLE staging_audit_results; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.staging_audit_results TO reflex_app_user;


--
-- Name: SEQUENCE staging_audit_results_staging_id_seq; Type: ACL; Schema: audit; Owner: -
--

GRANT ALL ON SEQUENCE audit.staging_audit_results_staging_id_seq TO reflex_app_user;


--
-- Name: TABLE staging_transactions; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.staging_transactions TO reflex_app_user;


--
-- Name: TABLE staging_transactions_20260701_231500; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.staging_transactions_20260701_231500 TO reflex_app_user;


--
-- Name: TABLE transactions_fullfields; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.transactions_fullfields TO reflex_app_user;


--
-- Name: TABLE v_audit_diff; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.v_audit_diff TO reflex_app_user;


--
-- Name: TABLE accounts; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.accounts TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.accounts TO reflex_app_user;


--
-- Name: TABLE addresses; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.addresses TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.addresses TO reflex_app_user;


--
-- Name: SEQUENCE addresses_code_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.addresses_code_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.addresses_code_seq TO reflex_app_user;


--
-- Name: TABLE contragents; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.contragents TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.contragents TO reflex_app_user;


--
-- Name: TABLE counterperyid_t_flw_037_3006; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.counterperyid_t_flw_037_3006 TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.counterperyid_t_flw_037_3006 TO reflex_app_user;


--
-- Name: TABLE dict_categories; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_categories TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_categories TO reflex_app_user;


--
-- Name: SEQUENCE dict_category_id_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.dict_category_id_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.dict_category_id_seq TO reflex_app_user;


--
-- Name: SEQUENCE dict_contragent_seq_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.dict_contragent_seq_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.dict_contragent_seq_seq TO reflex_app_user;


--
-- Name: TABLE dict_ledger_versions; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_ledger_versions TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_ledger_versions TO reflex_app_user;


--
-- Name: SEQUENCE dict_ledger_versions_version_id_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.dict_ledger_versions_version_id_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.dict_ledger_versions_version_id_seq TO reflex_app_user;


--
-- Name: TABLE dict_statuses; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_statuses TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_statuses TO reflex_app_user;


--
-- Name: TABLE dict_types; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_types TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_types TO reflex_app_user;


--
-- Name: TABLE dicts_currencies; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dicts_currencies TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dicts_currencies TO reflex_app_user;


--
-- Name: TABLE entities; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.entities TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.entities TO reflex_app_user;


--
-- Name: TABLE legal_entities; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.legal_entities TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.legal_entities TO reflex_app_user;


--
-- Name: SEQUENCE legal_entities_code_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.legal_entities_code_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.legal_entities_code_seq TO reflex_app_user;


--
-- Name: TABLE merchants; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.merchants TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.merchants TO reflex_app_user;


--
-- Name: SEQUENCE merchants_code_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.merchants_code_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.merchants_code_seq TO reflex_app_user;


--
-- Name: TABLE responsibles; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.responsibles TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.responsibles TO reflex_app_user;


--
-- Name: TABLE source_extractions; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.source_extractions TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.source_extractions TO reflex_app_user;


--
-- Name: TABLE aive_lock; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.aive_lock TO receipt_processor_svc;
GRANT ALL ON TABLE processing.aive_lock TO reflex_app_user;


--
-- Name: TABLE api_blocked_models; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.api_blocked_models TO receipt_processor_svc;
GRANT ALL ON TABLE processing.api_blocked_models TO reflex_app_user;


--
-- Name: TABLE api_request_blobs_cache; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.api_request_blobs_cache TO receipt_processor_svc;
GRANT ALL ON TABLE processing.api_request_blobs_cache TO reflex_app_user;


--
-- Name: TABLE api_requests_log; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.api_requests_log TO receipt_processor_svc;
GRANT ALL ON TABLE processing.api_requests_log TO reflex_app_user;


--
-- Name: TABLE api_requests_log_backup_120726_1339; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.api_requests_log_backup_120726_1339 TO receipt_processor_svc;
GRANT ALL ON TABLE processing.api_requests_log_backup_120726_1339 TO reflex_app_user;


--
-- Name: SEQUENCE api_requests_log_code_seq; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON SEQUENCE processing.api_requests_log_code_seq TO receipt_processor_svc;
GRANT ALL ON SEQUENCE processing.api_requests_log_code_seq TO reflex_app_user;


--
-- Name: TABLE receipts; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.receipts TO receipt_processor_svc;
GRANT ALL ON TABLE processing.receipts TO reflex_app_user;


--
-- Name: SEQUENCE receipts_code_seq; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON SEQUENCE processing.receipts_code_seq TO receipt_processor_svc;
GRANT ALL ON SEQUENCE processing.receipts_code_seq TO reflex_app_user;


--
-- Name: TABLE source_extractions; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.source_extractions TO receipt_processor_svc;
GRANT ALL ON TABLE processing.source_extractions TO reflex_app_user;


--
-- Name: SEQUENCE source_files_code_seq; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON SEQUENCE processing.source_files_code_seq TO receipt_processor_svc;
GRANT ALL ON SEQUENCE processing.source_files_code_seq TO reflex_app_user;


--
-- Name: TABLE source_files; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.source_files TO receipt_processor_svc;
GRANT ALL ON TABLE processing.source_files TO reflex_app_user;


--
-- Name: TABLE transaction_templates; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.transaction_templates TO reflex_app_user;
GRANT ALL ON TABLE processing.transaction_templates TO receipt_processor_svc;


--
-- Name: TABLE transaction_templates_20261023_123600; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.transaction_templates_20261023_123600 TO reflex_app_user;
GRANT ALL ON TABLE processing.transaction_templates_20261023_123600 TO receipt_processor_svc;


--
-- Name: TABLE vw_source_extractions_by_target; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.vw_source_extractions_by_target TO receipt_processor_svc;
GRANT ALL ON TABLE processing.vw_source_extractions_by_target TO reflex_app_user;


--
-- Name: TABLE registry; Type: ACL; Schema: projects; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE projects.registry TO reflex_app_user;


--
-- Name: TABLE acc_balance_snapshot_register; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.acc_balance_snapshot_register TO reflex_app_user;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.acc_balance_snapshot_register TO antigravity;


--
-- Name: TABLE chart_of_accounts; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.chart_of_accounts TO antigravity;


--
-- Name: TABLE contragent_precedents; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.contragent_precedents TO antigravity;


--
-- Name: TABLE ledger; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ledger TO antigravity;


--
-- Name: TABLE posting_rules; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.posting_rules TO antigravity;


--
-- Name: TABLE postings; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.postings TO antigravity;


--
-- Name: TABLE trigger_control; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.trigger_control TO antigravity;


--
-- Name: TABLE v_ledger_duck; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_ledger_duck TO antigravity;


--
-- Name: TABLE account_state_report; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.account_state_report TO reflex_app_user;


--
-- Name: TABLE ai_proxy_transactions; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.ai_proxy_transactions TO reflex_app_user;


--
-- Name: TABLE postings_detailed; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.postings_detailed TO reflex_app_user;


--
-- Name: TABLE system_verification_log; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.system_verification_log TO reflex_app_user;


--
-- Name: TABLE transactions; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.transactions TO reflex_app_user;


--
-- Name: TABLE trial_balance; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.trial_balance TO reflex_app_user;


--
-- Name: TABLE v_active_account_report; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_active_account_report TO reflex_app_user;


--
-- Name: TABLE v_current_projects; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_current_projects TO reflex_app_user;


--
-- Name: TABLE v_monthly_transactions_summary; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_monthly_transactions_summary TO reflex_app_user;


--
-- Name: TABLE v_textile_cohort_transactions; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_textile_cohort_transactions TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: audit; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA audit GRANT SELECT,USAGE ON SEQUENCES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA audit GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: dicts; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA dicts GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: processing; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA processing GRANT ALL ON SEQUENCES TO reflex_app_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA processing GRANT ALL ON SEQUENCES TO receipt_processor_svc;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: processing; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA processing GRANT ALL ON TABLES TO reflex_app_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA processing GRANT ALL ON TABLES TO receipt_processor_svc;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: projects; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA projects GRANT SELECT,USAGE ON SEQUENCES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: projects; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA projects GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO antigravity;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: reports; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA reports GRANT SELECT ON TABLES TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict RGPAFSFjSZSutQGgmSf8TbGxV2UQo7MPc2GCoK6Uvp5WjTpiKsVFzD6AL1kIFie

