--
-- PostgreSQL database dump
--

\restrict 8GgqjEvkME4lF84UCdnXteNDcEIp0GxvO2Ke8kgTd3qlXnRGp8Mqhqe2oTE2Hd5

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
-- Name: acc_balance_snapshot_register; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.acc_balance_snapshot_register (
    code integer CONSTRAINT "acc_balance_snapshot_register_Код_not_null" NOT NULL,
    account_id character varying(50),
    tr_id character varying(50),
    balance integer,
    registration_date date DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid()
);


--
-- Name: acc_balance_snapshot_register acc_balance_snapshot_register_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acc_balance_snapshot_register
    ADD CONSTRAINT acc_balance_snapshot_register_pkey PRIMARY KEY (code);


--
-- Name: acc_balance_snapshot_register trg_prevent_snapshot_modification; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_prevent_snapshot_modification BEFORE DELETE OR UPDATE ON public.acc_balance_snapshot_register FOR EACH ROW EXECUTE FUNCTION public.prevent_snapshot_modification();


--
-- Name: TABLE acc_balance_snapshot_register; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.acc_balance_snapshot_register TO reflex_app_user;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.acc_balance_snapshot_register TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict 8GgqjEvkME4lF84UCdnXteNDcEIp0GxvO2Ke8kgTd3qlXnRGp8Mqhqe2oTE2Hd5

