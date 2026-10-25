--
-- PostgreSQL database dump
--

\restrict NyDeGFp2MkdgxPshhuleTb6iL2ly3bjuIM9lwsdxRWt5xm9PFyd4QK0MHHWhjbJ

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
-- Name: reconciled_transactions_summary; Type: VIEW; Schema: texere; Owner: -
--

CREATE VIEW texere.reconciled_transactions_summary AS
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'materials_inventory'::text AS target_table,
    m.id AS record_id,
    m.name AS target_item_name,
    m.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.materials_inventory m ON (((m.transaction_uuid = t.uuid2) OR (m.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'consumables_inventory'::text AS target_table,
    c.id AS record_id,
    c.name AS target_item_name,
    c.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.consumables_inventory c ON (((c.transaction_uuid = t.uuid2) OR (c.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'patterns_inventory'::text AS target_table,
    p.id AS record_id,
    p.name AS target_item_name,
    p.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.patterns_inventory p ON (((p.transaction_uuid = t.uuid2) OR (p.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'tools_inventory'::text AS target_table,
    tool.id AS record_id,
    tool.name AS target_item_name,
    tool.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.tools_inventory tool ON (((tool.transaction_uuid = t.uuid2) OR (tool.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'external_services'::text AS target_table,
    s.id AS record_id,
    (((s.service_type)::text || ': '::text) || s.description) AS target_item_name,
    s.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.external_services s ON (((s.transaction_uuid = t.uuid2) OR (s.tx_code = t.tx_code))));


--
-- PostgreSQL database dump complete
--

\unrestrict NyDeGFp2MkdgxPshhuleTb6iL2ly3bjuIM9lwsdxRWt5xm9PFyd4QK0MHHWhjbJ

