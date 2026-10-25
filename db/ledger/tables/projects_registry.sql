--
-- PostgreSQL database dump
--

\restrict 7hB2QbgLNOUhhLDAfbpsjin4f1eE1Tb6JEdlGeElDmMbRchdwadVW4Ts3WACblR

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
-- Name: registry; Type: TABLE; Schema: projects; Owner: -
--

CREATE TABLE projects.registry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug character varying(64) NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: registry projects_pkey; Type: CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.registry
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: registry projects_slug_unique; Type: CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.registry
    ADD CONSTRAINT projects_slug_unique UNIQUE (slug);


--
-- Name: registry fk_projects_status; Type: FK CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.registry
    ADD CONSTRAINT fk_projects_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE registry; Type: ACL; Schema: projects; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE projects.registry TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 7hB2QbgLNOUhhLDAfbpsjin4f1eE1Tb6JEdlGeElDmMbRchdwadVW4Ts3WACblR

