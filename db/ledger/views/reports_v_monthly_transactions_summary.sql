--
-- PostgreSQL database dump
--

\restrict eqGL1KMeSrZUhzHKgpdn6FjybnYjFZDRy8IJyYNLywzH348KD4eIzRxqzWyOpeK

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
-- Name: TABLE v_monthly_transactions_summary; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_monthly_transactions_summary TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict eqGL1KMeSrZUhzHKgpdn6FjybnYjFZDRy8IJyYNLywzH348KD4eIzRxqzWyOpeK

