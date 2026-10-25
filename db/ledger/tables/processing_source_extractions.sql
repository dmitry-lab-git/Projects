--
-- PostgreSQL database dump
--

\restrict oeSYjS2IvwL4SOdg7dqej5QBhTSWzsZCjSFSrkhte1mYHzJK0QiAghR0waNCzeP

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
-- Name: source_extractions; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.source_extractions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    target_name character varying(100) NOT NULL
);


--
-- Name: source_extractions source_extractions_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_extractions
    ADD CONSTRAINT source_extractions_pkey PRIMARY KEY (id);


--
-- Name: idx_source_target_name; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_source_target_name ON processing.source_extractions USING btree (target_name);


--
-- Name: TABLE source_extractions; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.source_extractions TO receipt_processor_svc;
GRANT ALL ON TABLE processing.source_extractions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict oeSYjS2IvwL4SOdg7dqej5QBhTSWzsZCjSFSrkhte1mYHzJK0QiAghR0waNCzeP

