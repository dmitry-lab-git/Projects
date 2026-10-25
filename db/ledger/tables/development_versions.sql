--
-- PostgreSQL database dump
--

\restrict Eq4TjAsFhkMp8wHEMvCl1LKeskiK6n7XUlXfevEuJEsfSvnpuLevcBOQfM4AYCe

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
-- Name: versions; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.versions (
    code integer,
    version_name character varying(50),
    version_id character varying(50),
    version_code character varying(50),
    registration_date character varying(50),
    description character varying(1024),
    programming_stack character varying(100),
    dev_device character varying(100),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: versions versionregistry_t_unique_id; Type: CONSTRAINT; Schema: development; Owner: -
--

ALTER TABLE ONLY development.versions
    ADD CONSTRAINT versionregistry_t_unique_id UNIQUE (version_id);


--
-- PostgreSQL database dump complete
--

\unrestrict Eq4TjAsFhkMp8wHEMvCl1LKeskiK6n7XUlXfevEuJEsfSvnpuLevcBOQfM4AYCe

