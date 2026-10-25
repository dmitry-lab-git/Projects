--
-- PostgreSQL database dump
--

\restrict lMSkl8LfhHrzRHCLcm270ipIPx5hUNdJjUcB081ZSXGRMglXZQRvHXz0PjMo8Fj

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
-- Name: api_requests_log; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.api_requests_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_id uuid NOT NULL,
    model_family text NOT NULL,
    model_version text NOT NULL,
    status_id uuid NOT NULL,
    input_tokens integer DEFAULT 0,
    output_tokens integer DEFAULT 0,
    duration_ms integer,
    prompt_text text,
    response_text text,
    error_message text,
    file_meta jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: api_requests_log api_requests_log_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log
    ADD CONSTRAINT api_requests_log_pkey PRIMARY KEY (id);


--
-- Name: idx_api_log_created; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_created ON processing.api_requests_log USING btree (created_at);


--
-- Name: idx_api_log_meta; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_meta ON processing.api_requests_log USING gin (file_meta);


--
-- Name: idx_api_log_source_id; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_api_log_source_id ON processing.api_requests_log USING btree (source_id);


--
-- Name: api_requests_log trg_validate_request_log; Type: TRIGGER; Schema: processing; Owner: -
--

CREATE TRIGGER trg_validate_request_log BEFORE INSERT OR UPDATE ON processing.api_requests_log FOR EACH ROW EXECUTE FUNCTION processing.fn_validate_request_log();


--
-- Name: api_requests_log fk_api_requests_log_source; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log
    ADD CONSTRAINT fk_api_requests_log_source FOREIGN KEY (source_id) REFERENCES processing.source_extractions(id);


--
-- Name: api_requests_log fk_api_requests_log_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_requests_log
    ADD CONSTRAINT fk_api_requests_log_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE api_requests_log; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.api_requests_log TO receipt_processor_svc;
GRANT ALL ON TABLE processing.api_requests_log TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict lMSkl8LfhHrzRHCLcm270ipIPx5hUNdJjUcB081ZSXGRMglXZQRvHXz0PjMo8Fj

