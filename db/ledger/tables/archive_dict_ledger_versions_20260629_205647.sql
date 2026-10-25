--
-- PostgreSQL database dump
--

\restrict aehtoq6kndQN3CfN6EqhMs0vhrIWIDVjSanaIWRrVezbW91hreH3sQDuc4Vm7nk

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
-- Name: dict_ledger_versions_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.dict_ledger_versions_20260629_205647 (
    code integer,
    version_name text,
    version_code text,
    registration_date date,
    description text,
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- PostgreSQL database dump complete
--

\unrestrict aehtoq6kndQN3CfN6EqhMs0vhrIWIDVjSanaIWRrVezbW91hreH3sQDuc4Vm7nk

