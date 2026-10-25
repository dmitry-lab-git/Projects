--
-- PostgreSQL database dump
--

\restrict wuEo3PMXZFVnut2AOfV85ZoXLNjdNfqD1aBtjf6gO6vfHKHYgN8NO75nnxjcJcW

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
-- Name: measuring_devices; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.measuring_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_name character varying(255) NOT NULL,
    max_weight numeric(15,3),
    unit character varying(50),
    uncertainty numeric(10,4),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: measuring_devices measuring_devices_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.measuring_devices
    ADD CONSTRAINT measuring_devices_pkey PRIMARY KEY (id);


--
-- Name: TABLE measuring_devices; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.measuring_devices TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict wuEo3PMXZFVnut2AOfV85ZoXLNjdNfqD1aBtjf6gO6vfHKHYgN8NO75nnxjcJcW

