CREATE OR REPLACE FUNCTION public.fn_migrate_staging_to_transactions()
 RETURNS TABLE(out_code integer, out_transaction_id character varying, out_amount numeric)
 LANGUAGE plpgsql
AS $function$
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
$function$

