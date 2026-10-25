--
-- PostgreSQL database dump
--

\restrict DxKkkixmpgnFKFKHBTU3cPltFITMEQdEK5mOxtBQxPhvkA1Gga8bc6vI2s4gcpN

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
-- Name: TABLE trial_balance; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.trial_balance TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict DxKkkixmpgnFKFKHBTU3cPltFITMEQdEK5mOxtBQxPhvkA1Gga8bc6vI2s4gcpN

