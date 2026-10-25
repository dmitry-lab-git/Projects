--
-- PostgreSQL database dump
--

\restrict cX53sQJT690kh3XOi5RbOOCevUjO6r0ao2I0cm56AF9qeomcURwpEQb8LeTgOAi

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
-- Name: observations; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.observations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    observation_date date NOT NULL,
    notes text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: observations observations_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.observations
    ADD CONSTRAINT observations_pkey PRIMARY KEY (id);


--
-- Name: TABLE observations; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.observations TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict cX53sQJT690kh3XOi5RbOOCevUjO6r0ao2I0cm56AF9qeomcURwpEQb8LeTgOAi

