--
-- PostgreSQL database dump
--

\restrict UIuh9CqGwwINyi5j111SgJ5pVnGowKGdeCZ4aQgaaSPe5B2ithB8JoXdzyeU37C

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
-- Name: ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger (
    transaction_id integer NOT NULL,
    transaction_uuid uuid NOT NULL,
    name text,
    operation_date date NOT NULL,
    category_id character varying(50),
    amount numeric(19,4) NOT NULL,
    type_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    account_id character varying(50),
    acc_balance numeric(19,4) NOT NULL,
    system_balance numeric(19,4) NOT NULL,
    prev_acc_tr_id integer,
    prev_acc_tr_balance numeric(19,4) DEFAULT 0,
    check_sum character varying(64) NOT NULL
);


--
-- Name: ledger ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger
    ADD CONSTRAINT ledger_pkey PRIMARY KEY (transaction_id);


--
-- Name: idx_ledger_acc_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_acc_date ON public.ledger USING btree (account_id, operation_date);


--
-- Name: idx_ledger_tr_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_tr_uuid ON public.ledger USING btree (transaction_uuid);


--
-- Name: ledger trg_lock_ledger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lock_ledger BEFORE INSERT OR DELETE OR UPDATE ON public.ledger FOR EACH STATEMENT EXECUTE FUNCTION public.check_aive_lock();


--
-- Name: TABLE ledger; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ledger TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict UIuh9CqGwwINyi5j111SgJ5pVnGowKGdeCZ4aQgaaSPe5B2ithB8JoXdzyeU37C

