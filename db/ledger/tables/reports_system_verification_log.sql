--
-- PostgreSQL database dump
--

\restrict PtUoU4r0N5fs8uSXzY0ofupXHJpghnPYb0ZJpYd8GjCLSv1HFne1fl4h2YyJQtK

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
-- Name: system_verification_log; Type: TABLE; Schema: reports; Owner: -
--

CREATE TABLE reports.system_verification_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    verified_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    status_id uuid NOT NULL,
    total_accounts_processed integer NOT NULL,
    verified_count integer NOT NULL,
    total_balance_sum numeric(19,4) NOT NULL,
    verified_account_ids uuid[] NOT NULL,
    verification_hash character varying(64) NOT NULL
);


--
-- Name: system_verification_log system_verification_log_pkey; Type: CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.system_verification_log
    ADD CONSTRAINT system_verification_log_pkey PRIMARY KEY (id);


--
-- Name: system_verification_log uq_verification_hash; Type: CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.system_verification_log
    ADD CONSTRAINT uq_verification_hash UNIQUE (verification_hash);


--
-- Name: idx_sys_verification_log_date; Type: INDEX; Schema: reports; Owner: -
--

CREATE INDEX idx_sys_verification_log_date ON reports.system_verification_log USING btree (verified_at);


--
-- Name: system_verification_log fk_verification_log_status; Type: FK CONSTRAINT; Schema: reports; Owner: -
--

ALTER TABLE ONLY reports.system_verification_log
    ADD CONSTRAINT fk_verification_log_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE system_verification_log; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.system_verification_log TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict PtUoU4r0N5fs8uSXzY0ofupXHJpghnPYb0ZJpYd8GjCLSv1HFne1fl4h2YyJQtK

