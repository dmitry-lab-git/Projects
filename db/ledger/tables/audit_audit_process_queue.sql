--
-- PostgreSQL database dump
--

\restrict O0A69KRz9dEwb5MQtsDvAhL0tkMgv8bxTvTjz5Bax97zmPGkFV256FZDFECAtDN

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
-- Name: audit_process_queue; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.audit_process_queue (
    process_id integer NOT NULL,
    transaction_id uuid NOT NULL,
    audit_status character varying(20) DEFAULT 'pending'::character varying,
    last_processed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    api_attempt_count integer DEFAULT 0,
    error_message text,
    transaction_code integer
);


--
-- Name: audit_process_queue_process_id_seq; Type: SEQUENCE; Schema: audit; Owner: -
--

CREATE SEQUENCE audit.audit_process_queue_process_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_process_queue_process_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: -
--

ALTER SEQUENCE audit.audit_process_queue_process_id_seq OWNED BY audit.audit_process_queue.process_id;


--
-- Name: audit_process_queue process_id; Type: DEFAULT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_process_queue ALTER COLUMN process_id SET DEFAULT nextval('audit.audit_process_queue_process_id_seq'::regclass);


--
-- Name: audit_process_queue audit_process_queue_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_process_queue
    ADD CONSTRAINT audit_process_queue_pkey PRIMARY KEY (process_id);


--
-- Name: idx_queue_code; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_queue_code ON audit.audit_process_queue USING btree (transaction_code);


--
-- Name: idx_queue_status; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_queue_status ON audit.audit_process_queue USING btree (audit_status);


--
-- Name: audit_process_queue fk_transaction; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_process_queue
    ADD CONSTRAINT fk_transaction FOREIGN KEY (transaction_id) REFERENCES audit.transactions_fullfields(transaction_id);


--
-- Name: TABLE audit_process_queue; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.audit_process_queue TO reflex_app_user;


--
-- Name: SEQUENCE audit_process_queue_process_id_seq; Type: ACL; Schema: audit; Owner: -
--

GRANT ALL ON SEQUENCE audit.audit_process_queue_process_id_seq TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict O0A69KRz9dEwb5MQtsDvAhL0tkMgv8bxTvTjz5Bax97zmPGkFV256FZDFECAtDN

