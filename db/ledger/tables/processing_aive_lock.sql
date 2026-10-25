--
-- PostgreSQL database dump
--

\restrict 5UrZiPdhcMcPJ5Kf9FbYLzJjJ6MIoOdLjY3CXtWEhaTqr0XmSYFdvADC8Vl4Fjo

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
-- Name: aive_lock; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.aive_lock (
    lock_id integer DEFAULT 1 NOT NULL,
    is_locked boolean DEFAULT false,
    locked_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    protected_tables text DEFAULT 'transactions, ledger, dict_categories, dict_types, entities, contragents, acc_balance_snapshot_register'::text
);


--
-- Name: aive_lock aive_lock_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.aive_lock
    ADD CONSTRAINT aive_lock_pkey PRIMARY KEY (lock_id);


--
-- Name: TABLE aive_lock; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.aive_lock TO receipt_processor_svc;
GRANT ALL ON TABLE processing.aive_lock TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 5UrZiPdhcMcPJ5Kf9FbYLzJjJ6MIoOdLjY3CXtWEhaTqr0XmSYFdvADC8Vl4Fjo

