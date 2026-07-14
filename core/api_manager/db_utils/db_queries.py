QUERIES = {
    "INSERT_BLOB": """
        INSERT INTO processing.api_request_blobs_cache (request_id, file_data)
        VALUES (%s, %s);
    """,
    "BLOCK_MODEL_QUERY": """
        INSERT INTO processing.api_blocked_models (model_name, blocked_until)
        VALUES (%s, NOW() + (%s * INTERVAL '1 second'))
        ON CONFLICT (model_name) 
        DO UPDATE SET blocked_until = EXCLUDED.blocked_until;
    """,
    "CHECK_DUPLICATE": """
        SELECT id 
        FROM processing.api_requests_log 
        WHERE source_id = %s 
        LIMIT 1;
        """,
    "GET_START_TIME": """
        SELECT created_at 
        FROM processing.api_requests_log 
        WHERE id = %s;
        """,
    "CLEANUP_OLD_BLOBS": """
        DELETE FROM processing.api_request_blobs_cache 
        WHERE created_at < NOW() - INTERVAL '3 days';
    """,
    "CHECK_REQUEST_COUNT": """
        SELECT COUNT(*) as request_count 
        FROM processing.api_requests_log 
        WHERE created_at > clock_timestamp() - INTERVAL '1 minute';
    """,
    "GET_HEALTH_STATS": """
        SELECT 
            COUNT(*) FILTER (WHERE error_message LIKE %s) as req_limit,
            COUNT(*) FILTER (WHERE error_message LIKE %s) as tok_limit,
            COUNT(*) FILTER (WHERE created_at > clock_timestamp() - INTERVAL '10 minutes') as total_attempts
        FROM processing.api_requests_log
        WHERE (model_family || '-' || model_version) = %s
        AND created_at > (clock_timestamp() - INTERVAL '1 hour');
    """,
    "CLEANUP_PENDING": """
        UPDATE processing.api_requests_log
        SET status_id = %s, error_message = %s
        WHERE status_id = %s
        AND created_at < (NOW() AT TIME ZONE 'UTC' - INTERVAL %s);
    """,
    "CHECK_LOAD": """
        SELECT COUNT(id) 
        FROM processing.api_requests_log 
        WHERE created_at >= NOW() AT TIME ZONE 'UTC' - INTERVAL '5 seconds'
    """,
    "ENSURE_SOURCE_EXTRACTION": """
        INSERT INTO processing.source_extractions (id, target_name)
        VALUES (%s, %s)
        ON CONFLICT (id) 
        DO UPDATE SET target_name = EXCLUDED.target_name;
    """,
    "LOG_START": """
        INSERT INTO processing.api_requests_log 
        (source_id, model_family, model_version, prompt_text, file_meta, status_id, input_tokens)
        VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id;
    """,
    "LOG_FINISH": """
        UPDATE processing.api_requests_log 
        SET response_text = %s, status_id = %s, output_tokens = %s, 
            duration_ms = %s, error_message = %s
        WHERE id = %s;
    """,
    "LOG_RETRY": """
        UPDATE processing.api_requests_log 
        SET status_id = %s
        WHERE id = %s;
    """,
    # SQL-запрос с точечным расчетом скользящего окна RPM
    "GET_METRICS_REPORT": """
        WITH minute_stats AS (
            SELECT 
                COUNT(id) as global_rpm,
                COALESCE(SUM(COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)), 0) as global_tpm,
                MIN(created_at) as oldest_created_at
            FROM processing.api_requests_log
            -- Заменяем NOW() на clock_timestamp() для честного скользящего окна
            WHERE created_at >= clock_timestamp() - INTERVAL '1 minute'
            AND status_id != %s
        ),
        local_minute_stats AS (
            SELECT 
                COUNT(id) as local_rpm,
                COALESCE(SUM(COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)), 0) as local_tpm
            FROM processing.api_requests_log
            WHERE created_at >= clock_timestamp() - INTERVAL '1 minute'
            AND status_id != %s
            AND (model_family || '-' || model_version) = %s
        ),
        local_daily_stats AS (
            SELECT 
                COUNT(id) as total_quota_usage,
                COUNT(id) FILTER (WHERE status_id = %s) as successful_requests,
                ROUND((COUNT(id) FILTER (WHERE status_id = %s))::numeric / NULLIF(COUNT(id), 0) * 100, 2) as success_rate_percent
            FROM processing.api_requests_log
            WHERE created_at >= %s::timestamp
            AND (model_family || '-' || model_version) = %s
            AND status_id != %s
        )
        SELECT 
            m.global_rpm, 
            m.global_tpm,
            CASE 
                WHEN m.global_rpm >= %s THEN 
                    -- Заменяем NOW() на clock_timestamp() и в расчете разницы
                    GREATEST(EXTRACT(EPOCH FROM ((m.oldest_created_at + INTERVAL '1 minute') - clock_timestamp())), 0)
                ELSE 0 
            END as global_rpm_wait_sec,
            lm.local_rpm, lm.local_tpm,
            ld.total_quota_usage, ld.successful_requests, ld.success_rate_percent,
            clock_timestamp() as db_actual_clock,
            m.oldest_created_at as db_oldest_record
        FROM minute_stats m
        CROSS JOIN local_minute_stats lm 
        CROSS JOIN local_daily_stats ld;
    """
}