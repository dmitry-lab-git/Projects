--
-- PostgreSQL database dump
--

\restrict lR85AwkhwfVLhvZAd39TC4NfeP2HTSVurbslu16kekYtZaCdpteDgxv1SQJ1SuG

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
-- Name: dict_statuses; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dict_statuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_type character varying(50) NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: dict_statuses dict_statuses_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dict_statuses
    ADD CONSTRAINT dict_statuses_pkey PRIMARY KEY (id);


--
-- Name: idx_statuses_entity_type; Type: INDEX; Schema: dicts; Owner: -
--

CREATE INDEX idx_statuses_entity_type ON dicts.dict_statuses USING btree (entity_type);


--
-- Name: idx_unique_status_type_code; Type: INDEX; Schema: dicts; Owner: -
--

CREATE UNIQUE INDEX idx_unique_status_type_code ON dicts.dict_statuses USING btree (entity_type, code);


--
-- Name: TABLE dict_statuses; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dict_statuses TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dict_statuses TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict lR85AwkhwfVLhvZAd39TC4NfeP2HTSVurbslu16kekYtZaCdpteDgxv1SQJ1SuG

