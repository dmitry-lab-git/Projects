--
-- PostgreSQL database dump
--

\restrict YflnGRRrnKgBhTucam0djJVRUIQeQ292FwMZpGANJUuoCXEvQ1Jw2qtUC9njD3i

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
-- Name: responsibles_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.responsibles_20260629_205647 (
    code integer,
    resp_name character varying(50),
    responsible_id character varying(50),
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- PostgreSQL database dump complete
--

\unrestrict YflnGRRrnKgBhTucam0djJVRUIQeQ292FwMZpGANJUuoCXEvQ1Jw2qtUC9njD3i

