--
-- PostgreSQL database dump
--

\restrict RhdsVj4hd0IX6pY2XDAcZOFbvgSDIBg0aIxP5F1MPfUVVKwh5nekFZneT1pjgRG

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
-- Name: dict_types; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_types (
    code integer,
    type_name character varying(50),
    type_id character varying(50),
    net_value_effect character varying(50),
    account_effect numeric(19,4),
    needs_entity character varying(50),
    needs_project character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: dict_types dict_types_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_types
    ADD CONSTRAINT dict_types_code_unique UNIQUE (code);


--
-- Name: dict_types dict_types_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_types
    ADD CONSTRAINT dict_types_pkey PRIMARY KEY (id);


--
-- Name: TABLE dict_types; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_types TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_types TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict RhdsVj4hd0IX6pY2XDAcZOFbvgSDIBg0aIxP5F1MPfUVVKwh5nekFZneT1pjgRG

