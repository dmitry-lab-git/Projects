CREATE OR REPLACE FUNCTION public.get_mass_ddl(p_schema text, p_tables text[])
 RETURNS text
 LANGUAGE plpgsql
AS $function$
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
$function$

