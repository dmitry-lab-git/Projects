--
-- PostgreSQL database dump
--

\restrict u4fkbCoruKuTWW2lFGlqmD3u5U9WQUrBs1J1UpOLaY83ZTYLwsBUvPWf8TFsWYn

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
-- Name: staging_transactions_20260701_231500; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.staging_transactions_20260701_231500 (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT staging_transactions_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT staging_transactions_source_extraction_id_not_null NOT NULL,
    status_id_str character varying(20) DEFAULT 'NEW'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    transaction_name character varying(512),
    entity_id_str character varying(50),
    registration_date date,
    operation_date date,
    category_id_str character varying(50),
    responsible_id_str character varying(50),
    contragent_from_id_str character varying(50),
    contragent_to_id_str character varying(50),
    account_id_str character varying(50),
    type_id_str character varying(50),
    amount numeric(15,2),
    currency_id_str character varying(50),
    operation_time time without time zone,
    code integer
);


--
-- Name: staging_transactions_20260701_231500 staging_transactions_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_transactions_20260701_231500
    ADD CONSTRAINT staging_transactions_pkey PRIMARY KEY (id);


--
-- Name: idx_staging_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_status ON audit.staging_transactions_20260701_231500 USING btree (status_id_str);


--
-- Name: TABLE staging_transactions_20260701_231500; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.staging_transactions_20260701_231500 TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict u4fkbCoruKuTWW2lFGlqmD3u5U9WQUrBs1J1UpOLaY83ZTYLwsBUvPWf8TFsWYn

