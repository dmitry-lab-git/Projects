--
-- PostgreSQL database dump
--

\restrict VGVufithIZ26ClndMiLPYHEjpTrzaiObZqLypr85Bq5iPiePMkAuN5wfrxLsNWb

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
-- Name: source_files; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.source_files (
    id uuid CONSTRAINT source_photos_id_not_null NOT NULL,
    code integer DEFAULT nextval('processing.source_files_code_seq'::regclass) CONSTRAINT source_photos_code_not_null NOT NULL,
    file_name character varying(512) CONSTRAINT source_photos_file_name_not_null NOT NULL,
    file_path text CONSTRAINT source_photos_file_path_not_null NOT NULL,
    file_size bigint,
    device_source character varying(50) DEFAULT 'iPad'::character varying,
    upload_date date DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone CONSTRAINT source_photos_created_at_not_null NOT NULL,
    status_id uuid CONSTRAINT source_photos_status_id_not_null NOT NULL,
    file_hash character varying(64),
    parent_id uuid,
    reject_reason text
);


--
-- Name: source_files source_files_code_key; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_code_key UNIQUE (code);


--
-- Name: source_files source_files_hash_key; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_hash_key UNIQUE (file_hash);


--
-- Name: source_files source_files_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_pkey PRIMARY KEY (id);


--
-- Name: idx_source_files_hash; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_source_files_hash ON processing.source_files USING btree (file_hash);


--
-- Name: source_files source_files_parent_id_fkey; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.source_files
    ADD CONSTRAINT source_files_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES processing.source_files(id);


--
-- Name: TABLE source_files; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.source_files TO receipt_processor_svc;
GRANT ALL ON TABLE processing.source_files TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict VGVufithIZ26ClndMiLPYHEjpTrzaiObZqLypr85Bq5iPiePMkAuN5wfrxLsNWb

