--
-- PostgreSQL database dump
--

\restrict pXIrjyuFsyJ6l8eUALbLk46Wu7grQVOJAbsoXlBQH8YUXYlDT3UvT2UJTmeI48x

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
-- Name: file_versions; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.file_versions (
    "Код" integer,
    file_name character varying(50),
    file_version_id character varying(50),
    version_id character varying(50),
    created_at character varying(50),
    archived_at character varying(50),
    previous_file_version_id character varying(50),
    description character varying(50),
    id uuid DEFAULT public.uuid_generate_v4()
);


--
-- PostgreSQL database dump complete
--

\unrestrict pXIrjyuFsyJ6l8eUALbLk46Wu7grQVOJAbsoXlBQH8YUXYlDT3UvT2UJTmeI48x

