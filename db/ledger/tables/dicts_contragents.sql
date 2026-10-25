--
-- PostgreSQL database dump
--

\restrict mYNXdUukl0dEBtf9UnxIK3WkF0FckbwE8s5oIsfVOsDXL7nh9g6zMOLQJfZjurD

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
-- Name: contragents; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.contragents (
    code integer CONSTRAINT dict_contragent_seq_not_null NOT NULL,
    contragent_name character varying(50),
    contragent_id character varying(50),
    contragent_type character varying(50),
    description character varying(512),
    id uuid DEFAULT gen_random_uuid() CONSTRAINT contragent_register_id_not_null NOT NULL,
    address_id uuid,
    keywords text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status_id uuid NOT NULL,
    merchant_id uuid,
    legal_entity_id uuid
);


--
-- Name: dict_contragent_seq_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.dict_contragent_seq_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dict_contragent_seq_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.dict_contragent_seq_seq OWNED BY dicts.contragents.code;


--
-- Name: contragents code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents ALTER COLUMN code SET DEFAULT nextval('dicts.dict_contragent_seq_seq'::regclass);


--
-- Name: contragents contragents_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT contragents_code_unique UNIQUE (code);


--
-- Name: contragents contragents_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT contragents_pkey PRIMARY KEY (id);


--
-- Name: idx_contragents_merchant; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_contragents_merchant ON dicts.contragents USING btree (merchant_id);


--
-- Name: contragents contragents_merchant_id_fkey; Type: FK CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT contragents_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES dicts.merchants(id);


--
-- Name: contragents fk_contragent_legal_entity; Type: FK CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.contragents
    ADD CONSTRAINT fk_contragent_legal_entity FOREIGN KEY (legal_entity_id) REFERENCES dicts.legal_entities(id);


--
-- Name: TABLE contragents; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.contragents TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.contragents TO reflex_app_user;


--
-- Name: SEQUENCE dict_contragent_seq_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.dict_contragent_seq_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.dict_contragent_seq_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict mYNXdUukl0dEBtf9UnxIK3WkF0FckbwE8s5oIsfVOsDXL7nh9g6zMOLQJfZjurD

