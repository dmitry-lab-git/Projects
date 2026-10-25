--
-- PostgreSQL database dump
--

\restrict 30uAzPb3iOtDzDXAJWCxclOfgB5WcYppb3AJGXzLgYEDB3XSiAtWqBKYYAJ6BD2

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
-- Name: v_active_account_report; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.v_active_account_report AS
 SELECT account_id,
    account_name,
    balance,
    account_balance_status,
    last_updated
   FROM reports.account_state_report
  WHERE (((account_state)::text = 'active'::text) AND (balance <> (0)::numeric))
  ORDER BY balance DESC;


--
-- Name: TABLE v_active_account_report; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_active_account_report TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 30uAzPb3iOtDzDXAJWCxclOfgB5WcYppb3AJGXzLgYEDB3XSiAtWqBKYYAJ6BD2

