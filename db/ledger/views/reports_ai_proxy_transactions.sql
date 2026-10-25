--
-- PostgreSQL database dump
--

\restrict GRdJVDJspktjdFbj08k8hpShjU743jqvsgKcdzrZtQ65Uqwm3OrlPFUqYDY2cDP

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
-- Name: TABLE ai_proxy_transactions; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.ai_proxy_transactions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict GRdJVDJspktjdFbj08k8hpShjU743jqvsgKcdzrZtQ65Uqwm3OrlPFUqYDY2cDP

