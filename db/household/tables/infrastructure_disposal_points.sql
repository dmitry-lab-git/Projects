--
-- PostgreSQL database dump
--

\restrict hlpO4KAm7vzMpY65VqkBVLX5ADOgtoLWyeV5wo9iyzFKnOB6CktGEtxWwiJAjcT

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
-- Name: disposal_points; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.disposal_points (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255),
    type character varying(255),
    coordinates public.geography(Point,4326) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    contragent_id uuid
);


--
-- Name: disposal_points disposal_points_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.disposal_points
    ADD CONSTRAINT disposal_points_pkey PRIMARY KEY (id);


--
-- Name: TABLE disposal_points; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.disposal_points TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict hlpO4KAm7vzMpY65VqkBVLX5ADOgtoLWyeV5wo9iyzFKnOB6CktGEtxWwiJAjcT

