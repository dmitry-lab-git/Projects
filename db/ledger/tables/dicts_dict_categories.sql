--
-- PostgreSQL database dump
--

\restrict VtbUEOEbdX0CkxNFuDv1FvqaISgBMFrka3WXBJD3ObSfaAjCVbdwjnJSjR3oNFJ

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
-- Name: dict_categories; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_categories (
    code integer CONSTRAINT dict_category_id_not_null NOT NULL,
    category_name character varying(255) CONSTRAINT dict_category_category_name_not_null NOT NULL,
    category_id character varying(50) CONSTRAINT dict_category_category_id_not_null NOT NULL,
    parent_category_id character varying(50),
    keywords text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: dict_category_id_seq; Type: SEQUENCE; Schema: dicts; Owner: -
--

CREATE SEQUENCE dicts.dict_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dict_category_id_seq; Type: SEQUENCE OWNED BY; Schema: dicts; Owner: -
--

ALTER SEQUENCE dicts.dict_category_id_seq OWNED BY dicts.dict_categories.code;


--
-- Name: dict_categories code; Type: DEFAULT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_categories ALTER COLUMN code SET DEFAULT nextval('dicts.dict_category_id_seq'::regclass);


--
-- Name: dict_categories dict_categories_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_categories
    ADD CONSTRAINT dict_categories_code_unique UNIQUE (code);


--
-- Name: dict_categories dict_categories_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_categories
    ADD CONSTRAINT dict_categories_pkey PRIMARY KEY (id);


--
-- Name: TABLE dict_categories; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_categories TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_categories TO reflex_app_user;


--
-- Name: SEQUENCE dict_category_id_seq; Type: ACL; Schema: dicts; Owner: -
--

GRANT ALL ON SEQUENCE dicts.dict_category_id_seq TO receipt_processor_svc;
GRANT SELECT,USAGE ON SEQUENCE dicts.dict_category_id_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict VtbUEOEbdX0CkxNFuDv1FvqaISgBMFrka3WXBJD3ObSfaAjCVbdwjnJSjR3oNFJ

