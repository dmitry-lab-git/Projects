--
-- PostgreSQL database dump
--

\restrict 3ubpfpp3yWJbeufZpcDrV9YBwbGpd93DPotdSLa1TItwZH51pbFN73cyLv6o6T2

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
-- Name: metadata; Type: TABLE; Schema: projects; Owner: -
--

CREATE TABLE projects.metadata (
    project_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: metadata projects_metadata_pkey; Type: CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.metadata
    ADD CONSTRAINT projects_metadata_pkey PRIMARY KEY (project_id);


--
-- Name: idx_projects_metadata_meta; Type: INDEX; Schema: projects; Owner: -
--

CREATE INDEX idx_projects_metadata_meta ON projects.metadata USING gin (meta);


--
-- Name: TABLE metadata; Type: ACL; Schema: projects; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE projects.metadata TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 3ubpfpp3yWJbeufZpcDrV9YBwbGpd93DPotdSLa1TItwZH51pbFN73cyLv6o6T2

