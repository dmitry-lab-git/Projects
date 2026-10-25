--
-- PostgreSQL database dump
--

\restrict Gt6R8uQabtS6K7lHD2qgwmxUVnScAMPMOKcWW87a3MzRn64Ac5KxrbSplbAcSAq

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
-- Name: v_product_registry_analytics; Type: VIEW; Schema: texere; Owner: -
--

CREATE VIEW texere.v_product_registry_analytics AS
 SELECT id,
    title,
    completion_date,
    quantity,
        CASE
            WHEN (jsonb_typeof((meta -> 'tags'::text)) = 'array'::text) THEN ARRAY( SELECT jsonb_array_elements_text((p.meta -> 'tags'::text)) AS jsonb_array_elements_text)
            ELSE ARRAY[]::text[]
        END AS categories,
    quality_rating,
    project_cost_kzt,
    (NULLIF((meta ->> 'material_costs_kzt'::text), ''::text))::numeric AS material_costs_kzt,
    (NULLIF((meta ->> 'labor_costs_kzt'::text), ''::text))::numeric AS labor_costs_kzt,
    COALESCE(( SELECT sum((NULLIF((f.item ->> 'consumption_m'::text), ''::text))::numeric) AS sum
           FROM jsonb_array_elements(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'fabrics'::text)) = 'array'::text) THEN (p.materials -> 'fabrics'::text)
                    ELSE '[]'::jsonb
                END) f(item)), (0)::numeric) AS fabrics_consumption_m,
    COALESCE(( SELECT sum(COALESCE((NULLIF((i.item ->> 'total_consumption_m'::text), ''::text))::numeric, (NULLIF((i.item ->> 'consumption_m'::text), ''::text))::numeric, (0)::numeric)) AS sum
           FROM jsonb_each(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'items'::text)) = 'object'::text) THEN (p.materials -> 'items'::text)
                    ELSE '{}'::jsonb
                END) i(component_name, item)), (0)::numeric) AS items_consumption_m,
    (COALESCE(( SELECT sum((NULLIF((f.item ->> 'consumption_m'::text), ''::text))::numeric) AS sum
           FROM jsonb_array_elements(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'fabrics'::text)) = 'array'::text) THEN (p.materials -> 'fabrics'::text)
                    ELSE '[]'::jsonb
                END) f(item)), (0)::numeric) + COALESCE(( SELECT sum(COALESCE((NULLIF((i.item ->> 'total_consumption_m'::text), ''::text))::numeric, (NULLIF((i.item ->> 'consumption_m'::text), ''::text))::numeric, (0)::numeric)) AS sum
           FROM jsonb_each(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'items'::text)) = 'object'::text) THEN (p.materials -> 'items'::text)
                    ELSE '{}'::jsonb
                END) i(component_name, item)), (0)::numeric)) AS recorded_fabric_consumption_m,
    COALESCE(((meta ->> 'data_checked'::text))::boolean, false) AS data_checked,
    is_published,
    original_photo,
    processed_photo
   FROM texere.product_registry p;


--
-- PostgreSQL database dump complete
--

\unrestrict Gt6R8uQabtS6K7lHD2qgwmxUVnScAMPMOKcWW87a3MzRn64Ac5KxrbSplbAcSAq

