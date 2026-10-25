--
-- PostgreSQL database dump
--

\restrict gSGYrnbhFKBbWj8nBoeIV5XRbexzcojWzQoyQ9cXeQdkogwhoC21mJPPoWcjc6H

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
-- Name: version_updates; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.version_updates (
    code integer DEFAULT nextval('development.version_updates_code_seq'::regclass),
    update_version_name character varying(50),
    update_version_id character varying(50),
    version_id character varying(50),
    registration_date date NOT NULL,
    description text,
    affected_objects text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: COLUMN version_updates.update_version_id; Type: COMMENT; Schema: development; Owner: -
--

COMMENT ON COLUMN development.version_updates.update_version_id IS 'Идентификатор конкретного обновления (напр. UVR-002)';


--
-- Name: COLUMN version_updates.version_id; Type: COMMENT; Schema: development; Owner: -
--

COMMENT ON COLUMN development.version_updates.version_id IS 'Ссылка на основную версию системы (напр. VER-003)';


--
-- Name: version_updates trg_version_updates_insert; Type: TRIGGER; Schema: development; Owner: -
--

CREATE TRIGGER trg_version_updates_insert BEFORE INSERT ON development.version_updates FOR EACH ROW EXECUTE FUNCTION development.fn_auto_generate_uvr();


--
-- PostgreSQL database dump complete
--

\unrestrict gSGYrnbhFKBbWj8nBoeIV5XRbexzcojWzQoyQ9cXeQdkogwhoC21mJPPoWcjc6H

