--
-- PostgreSQL database dump
--

\restrict tKd3QVnlkhaSU2HER4VxjVgeHePNAIpg1GbMYt4adiDj0LtmHseDoQPLCIV0oj3

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
-- Name: responsibles; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.responsibles (
    code integer,
    resp_name character varying(50),
    responsible_id character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: responsibles responsibles_code_unique; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.responsibles
    ADD CONSTRAINT responsibles_code_unique UNIQUE (code);


--
-- Name: responsibles responsibles_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.responsibles
    ADD CONSTRAINT responsibles_pkey PRIMARY KEY (id);


--
-- Name: TABLE responsibles; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.responsibles TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.responsibles TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict tKd3QVnlkhaSU2HER4VxjVgeHePNAIpg1GbMYt4adiDj0LtmHseDoQPLCIV0oj3

