--
-- PostgreSQL database dump
--

\restrict wvs6dluJDtaHElR4jnAm6FyhmArL1rd3ajUtRbN8tYkJOAC2z0qcte1ErgeAehn

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
-- Name: TABLE postings_detailed; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.postings_detailed TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict wvs6dluJDtaHElR4jnAm6FyhmArL1rd3ajUtRbN8tYkJOAC2z0qcte1ErgeAehn

