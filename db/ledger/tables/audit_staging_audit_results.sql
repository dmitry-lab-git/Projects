--
-- PostgreSQL database dump
--

\restrict df8qgndBKOZtGSe4ZMOZqA5XFNXkdoLafgRc48bBbaXtq5AdUgRMfLc3ZeJRI8p

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
-- Name: staging_audit_results; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.staging_audit_results (
    staging_id integer NOT NULL,
    transaction_id uuid NOT NULL,
    status character varying(50),
    diff_json jsonb,
    reasoning text,
    raw_response jsonb,
    is_applied boolean DEFAULT false,
    applied_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    code integer,
    audit_type character varying(20) DEFAULT 'primary'::character varying,
    parent_staging_id integer,
    audit_id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_extraction_id uuid
);


--
-- Name: staging_audit_results_staging_id_seq; Type: SEQUENCE; Schema: audit; Owner: -
--

CREATE SEQUENCE audit.staging_audit_results_staging_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staging_audit_results_staging_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: -
--

ALTER SEQUENCE audit.staging_audit_results_staging_id_seq OWNED BY audit.staging_audit_results.staging_id;


--
-- Name: staging_audit_results staging_id; Type: DEFAULT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_audit_results ALTER COLUMN staging_id SET DEFAULT nextval('audit.staging_audit_results_staging_id_seq'::regclass);


--
-- Name: staging_audit_results staging_audit_results_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_audit_results
    ADD CONSTRAINT staging_audit_results_pkey PRIMARY KEY (staging_id);


--
-- Name: idx_staging_code; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_code ON audit.staging_audit_results USING btree (code);


--
-- Name: idx_staging_pending; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_staging_pending ON audit.staging_audit_results USING btree (transaction_id) WHERE (is_applied = false);


--
-- Name: staging_audit_results fk_staging_source_extraction; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.staging_audit_results
    ADD CONSTRAINT fk_staging_source_extraction FOREIGN KEY (source_extraction_id) REFERENCES processing.source_extractions(id) ON DELETE SET NULL;


--
-- Name: TABLE staging_audit_results; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.staging_audit_results TO reflex_app_user;


--
-- Name: SEQUENCE staging_audit_results_staging_id_seq; Type: ACL; Schema: audit; Owner: -
--

GRANT ALL ON SEQUENCE audit.staging_audit_results_staging_id_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict df8qgndBKOZtGSe4ZMOZqA5XFNXkdoLafgRc48bBbaXtq5AdUgRMfLc3ZeJRI8p

