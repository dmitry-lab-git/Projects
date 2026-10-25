--
-- PostgreSQL database dump
--

\restrict X3sgexw8lJZYA1bjSMNDXLdrQtDV2uzh5ELuSbenJKcCYguyAIiPqc703uqMnR4

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
-- Name: merchants; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.merchants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code integer NOT NULL,
    merchant_name character varying(100) NOT NULL,
    default_legal_entity_id uuid,
    status_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: merchants_code_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.merchants_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merchants_code_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.merchants_code_seq OWNED BY dicts.merchants.code;


--
-- Name: merchants code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants ALTER COLUMN code SET DEFAULT nextval('dicts.merchants_code_seq'::regclass);


--
-- Name: merchants merchants_code_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants
    ADD CONSTRAINT merchants_code_key UNIQUE (code);


--
-- Name: merchants merchants_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants
    ADD CONSTRAINT merchants_pkey PRIMARY KEY (id);


--
-- Name: idx_merchants_legal_entity; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_merchants_legal_entity ON dicts.merchants USING btree (default_legal_entity_id);


--
-- Name: merchants merchants_default_legal_entity_id_fkey; Type: FK CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.merchants
    ADD CONSTRAINT merchants_default_legal_entity_id_fkey FOREIGN KEY (default_legal_entity_id) REFERENCES dicts.legal_entities(id);


--
-- Name: TABLE merchants; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.merchants TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.merchants TO reflex_app_user;


--
-- Name: SEQUENCE merchants_code_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.merchants_code_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.merchants_code_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict X3sgexw8lJZYA1bjSMNDXLdrQtDV2uzh5ELuSbenJKcCYguyAIiPqc703uqMnR4

