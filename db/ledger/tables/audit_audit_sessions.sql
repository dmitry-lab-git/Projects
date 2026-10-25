--
-- PostgreSQL database dump
--

\restrict 05hclDno9baylsl07zilUHy2B67KcDDT600Mm37UXuhy15S7wrEkyGDV8iy1N2H

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
-- Name: audit_sessions; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.audit_sessions (
    iteration_type character varying(50),
    seq integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    finished_at timestamp without time zone,
    status character varying(20),
    results_description text,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE audit_sessions; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.audit_sessions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 05hclDno9baylsl07zilUHy2B67KcDDT600Mm37UXuhy15S7wrEkyGDV8iy1N2H

