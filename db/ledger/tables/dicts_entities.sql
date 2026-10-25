--
-- PostgreSQL database dump
--

\restrict mAkt73b9JvksQL8iaT3QcnTolVvBcjjZEeAnJbiiAVfqRCjpfIvA07nRO29p7sq

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
-- Name: entities; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.entities (
    code integer NOT NULL,
    entity_name character varying(50),
    entity_id character varying(50),
    category_id character varying(50),
    keywords text[] DEFAULT '{}'::text[],
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: entities entities_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.entities
    ADD CONSTRAINT entities_code_unique UNIQUE (code);


--
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- Name: TABLE entities; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.entities TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.entities TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict mAkt73b9JvksQL8iaT3QcnTolVvBcjjZEeAnJbiiAVfqRCjpfIvA07nRO29p7sq

