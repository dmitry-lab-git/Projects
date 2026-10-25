--
-- PostgreSQL database dump
--

\restrict euXaNuv8VbzfrdeoXvjWwbAUXgsqlP1sFIIuSO2aYjw4H8usFb2ujpzJwYqASwm

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
-- Name: legal_entities; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.legal_entities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code integer NOT NULL,
    legal_name character varying(255) NOT NULL,
    tax_number character varying(20) NOT NULL,
    registration_number character varying(20),
    legal_address text,
    status_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: legal_entities_code_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.legal_entities_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: legal_entities_code_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.legal_entities_code_seq OWNED BY dicts.legal_entities.code;


--
-- Name: legal_entities code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities ALTER COLUMN code SET DEFAULT nextval('dicts.legal_entities_code_seq'::regclass);


--
-- Name: legal_entities legal_entities_code_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities
    ADD CONSTRAINT legal_entities_code_key UNIQUE (code);


--
-- Name: legal_entities legal_entities_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities
    ADD CONSTRAINT legal_entities_pkey PRIMARY KEY (id);


--
-- Name: legal_entities legal_entities_tax_number_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.legal_entities
    ADD CONSTRAINT legal_entities_tax_number_key UNIQUE (tax_number);


--
-- Name: idx_legal_entities_tax; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_legal_entities_tax ON dicts.legal_entities USING btree (tax_number);


--
-- Name: TABLE legal_entities; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.legal_entities TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.legal_entities TO reflex_app_user;


--
-- Name: SEQUENCE legal_entities_code_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.legal_entities_code_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.legal_entities_code_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict euXaNuv8VbzfrdeoXvjWwbAUXgsqlP1sFIIuSO2aYjw4H8usFb2ujpzJwYqASwm

