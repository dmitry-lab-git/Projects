--
-- PostgreSQL database dump
--

\restrict q9GIpDapZZODZDxtkwyk8K50KeYZB2MfMfTG1bUWuz3DCWeGc3RtOMXGeZSmizr

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
-- Name: trigger_control_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.trigger_control_20260629_205647 (
    trigger_name text,
    is_enabled boolean,
    description text,
    updated_at timestamp without time zone
);


--
-- PostgreSQL database dump complete
--

\unrestrict q9GIpDapZZODZDxtkwyk8K50KeYZB2MfMfTG1bUWuz3DCWeGc3RtOMXGeZSmizr

