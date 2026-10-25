--
-- PostgreSQL database dump
--

\restrict pUs6UtpK66KOZJcLSuJpRaOfoekpYm50Mp6kefTPTribU1NYyQAPebpm82UQMQz

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
-- Name: staging_transactions; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.staging_transactions (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT staging_transactions_v1_1_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT staging_transactions_v1_1_source_extraction_id_not_null NOT NULL,
    status_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    transaction_name character varying(512),
    entity_id uuid,
    registration_date date,
    operation_date date,
    category_id uuid,
    responsible_id uuid,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid,
    type_id uuid,
    amount numeric(19,4),
    currency_id uuid,
    operation_time time without time zone,
    code integer
);


--
-- Name: staging_transactions staging_transactions_v1_1_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions
    ADD CONSTRAINT staging_transactions_v1_1_pkey PRIMARY KEY (id);


--
-- Name: idx_staging_v1_1_operation_time; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_v1_1_operation_time ON audit.staging_transactions USING btree (operation_date, operation_time);


--
-- Name: idx_staging_v1_1_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_v1_1_status ON audit.staging_transactions USING btree (status_id);


--
-- Name: staging_transactions fk_staging_v1_1_account; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions
    ADD CONSTRAINT fk_staging_v1_1_account FOREIGN KEY (account_id) REFERENCES dicts.accounts(id);


--
-- Name: staging_transactions fk_staging_v1_1_status; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions
    ADD CONSTRAINT fk_staging_v1_1_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE staging_transactions; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.staging_transactions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict pUs6UtpK66KOZJcLSuJpRaOfoekpYm50Mp6kefTPTribU1NYyQAPebpm82UQMQz

