--
-- PostgreSQL database dump
--

\restrict Kcw8oX94xnJ1ZvRpyfTZyiorBwkxERMqClNT6z4FhNTsI1Z2QTljtscfEIvO9aH

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_state_report; Type: TABLE; Schema: reports; Owner: -
--

CREATE TABLE reports.account_state_report (
    account_id character varying(50) CONSTRAINT "account_state_report_AccID_not_null" NOT NULL,
    account_name character varying(100),
    entity character varying(100),
    balance numeric(19,4),
    account_balance_status character varying(50),
    last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    account_state character varying(20),
    snapshot_tr_id integer,
    acc_last_tr_id integer,
    acc_balance_snapshot_balance numeric(19,4)
);


--
-- Name: account_state_report account_state_report_pkey; Type: CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.account_state_report
    ADD CONSTRAINT account_state_report_pkey PRIMARY KEY (account_id);


--
-- Name: TABLE account_state_report; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.account_state_report TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict Kcw8oX94xnJ1ZvRpyfTZyiorBwkxERMqClNT6z4FhNTsI1Z2QTljtscfEIvO9aH

