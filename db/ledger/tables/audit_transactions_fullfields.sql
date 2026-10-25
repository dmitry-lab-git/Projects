--
-- PostgreSQL database dump
--

\restrict UU6DVNJCV7m8LTfmNz98rPfokxJ5fkTwapj0J21cdjJvubvlWvLmErLhuaDZznB

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
-- Name: transactions_fullfields; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.transactions_fullfields (
    transaction_id uuid NOT NULL,
    transaction_name character varying(1024),
    entity_id character varying(50),
    entity_name character varying(100),
    category_id character varying(50),
    category_name character varying(255),
    contragent_from_id character varying(50),
    contragent_from_name character varying(100),
    contragent_to_id character varying(50),
    contragent_to_name character varying(100),
    account_id character varying(50),
    account_name character varying(100),
    type_id character varying(50),
    type_name character varying(50),
    amount numeric,
    tr_currency character varying(50),
    operation_date date,
    keywords text[],
    code integer,
    last_audited_at timestamp without time zone,
    audit_status character varying(20) DEFAULT 'pending'::character varying,
    ai_comment text,
    acc_balance numeric(19,4),
    prev_acc_tr_balance numeric(19,4),
    prev_acc_tr_id integer,
    transaction_code integer
);


--
-- Name: transactions_fullfields transactions_fullfields_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.transactions_fullfields
    ADD CONSTRAINT transactions_fullfields_pkey PRIMARY KEY (transaction_id);


--
-- Name: idx_audit_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_status ON audit.transactions_fullfields USING btree (audit_status);


--
-- Name: idx_fullfields_code; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_fullfields_code ON audit.transactions_fullfields USING btree (transaction_code);


--
-- Name: idx_transactions_fullfields_keywords; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_transactions_fullfields_keywords ON audit.transactions_fullfields USING gin (keywords);


--
-- Name: transactions_fullfields transactions_fullfields_transaction_id_fkey; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.transactions_fullfields
    ADD CONSTRAINT transactions_fullfields_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: TABLE transactions_fullfields; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.transactions_fullfields TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict UU6DVNJCV7m8LTfmNz98rPfokxJ5fkTwapj0J21cdjJvubvlWvLmErLhuaDZznB

