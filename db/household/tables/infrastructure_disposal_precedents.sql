--
-- PostgreSQL database dump
--

\restrict BW8CpedcLCnwgwlClVsSIURQWQe7WOGEyMpQ6jSCDzjrI8gcvurjCEpxQFEOfCB

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
-- Name: disposal_precedents; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.disposal_precedents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_disposition_id uuid NOT NULL,
    precedent_name character varying(255) NOT NULL,
    unit_type character varying(50) NOT NULL,
    quantity numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    notes text
);


--
-- Name: disposal_precedents disposal_precedents_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.disposal_precedents
    ADD CONSTRAINT disposal_precedents_pkey PRIMARY KEY (id);


--
-- Name: TABLE disposal_precedents; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.disposal_precedents TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict BW8CpedcLCnwgwlClVsSIURQWQe7WOGEyMpQ6jSCDzjrI8gcvurjCEpxQFEOfCB

