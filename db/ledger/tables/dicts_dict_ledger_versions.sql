--
-- PostgreSQL database dump
--

\restrict 3l2vVCig9UZSAQXSG23M7iCiFWFCxZBu1MDe5R4JzG0JdbLSFCQWIBpDT6f3BQ9

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
-- Name: dict_ledger_versions; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_ledger_versions (
    code integer CONSTRAINT dict_ledger_versions_version_id_not_null NOT NULL,
    version_name text NOT NULL,
    version_code text NOT NULL,
    registration_date date CONSTRAINT dict_ledger_versions_created_at_not_null NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL,
    CONSTRAINT chk_version_desc_length CHECK ((char_length(description) > 10))
);


--
-- Name: dict_ledger_versions_version_id_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.dict_ledger_versions_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dict_ledger_versions_version_id_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.dict_ledger_versions_version_id_seq OWNED BY dicts.dict_ledger_versions.code;


--
-- Name: dict_ledger_versions code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_ledger_versions ALTER COLUMN code SET DEFAULT nextval('dicts.dict_ledger_versions_version_id_seq'::regclass);


--
-- Name: dict_ledger_versions dict_ledger_versions_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_ledger_versions
    ADD CONSTRAINT dict_ledger_versions_pkey PRIMARY KEY (id);


--
-- Name: TABLE dict_ledger_versions; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_ledger_versions TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_ledger_versions TO reflex_app_user;


--
-- Name: SEQUENCE dict_ledger_versions_version_id_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.dict_ledger_versions_version_id_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.dict_ledger_versions_version_id_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 3l2vVCig9UZSAQXSG23M7iCiFWFCxZBu1MDe5R4JzG0JdbLSFCQWIBpDT6f3BQ9

