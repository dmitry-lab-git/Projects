--
-- PostgreSQL database dump
--

\restrict 1dV45wNqdE9yaacSL3yp2EJEy9uyx4lG7XcMe4SmQVzdNaJ3p4bMeR0nW9tf3Fe

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
-- Name: TABLE v_textile_cohort_transactions; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_textile_cohort_transactions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 1dV45wNqdE9yaacSL3yp2EJEy9uyx4lG7XcMe4SmQVzdNaJ3p4bMeR0nW9tf3Fe

