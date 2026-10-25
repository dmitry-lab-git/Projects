--
-- PostgreSQL database dump
--

\restrict vwc06TrqxZIfbP7W7553VV5C0Pkmikw1l0lScaMgjAKmuAU53YlDo6CSuHJYqNn

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
-- Name: resource_catalog; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.resource_catalog (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_name character varying(255) NOT NULL,
    resource_type character varying(100),
    default_unit character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    container_type character varying(100),
    notes text
);


--
-- Name: resource_catalog resource_catalog_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.resource_catalog
    ADD CONSTRAINT resource_catalog_pkey PRIMARY KEY (id);


--
-- Name: idx_resource_name; Type: INDEX; Schema: infrastructure; Owner: -
--

CREATE INDEX idx_resource_name ON infrastructure.resource_catalog USING btree (material_name);


--
-- Name: TABLE resource_catalog; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.resource_catalog TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict vwc06TrqxZIfbP7W7553VV5C0Pkmikw1l0lScaMgjAKmuAU53YlDo6CSuHJYqNn

