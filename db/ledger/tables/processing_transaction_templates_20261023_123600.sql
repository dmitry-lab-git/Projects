--
-- PostgreSQL database dump
--

\restrict OHEaqiDaiLvgWRN5HFh80lBQTqJyGbDErH5QMg3JqGEdPiMc3BdW6JtcOvT2ZA5

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
-- Name: transaction_templates_20261023_123600; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.transaction_templates_20261023_123600 (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transaction_templates_id_not_null NOT NULL,
    transaction_name character varying(150) CONSTRAINT transaction_templates_transaction_name_not_null NOT NULL,
    amount numeric(15,2),
    currency_id_str character varying(50),
    type_id_str character varying(50),
    entity_id_str character varying(50),
    category_id_str character varying(50),
    responsible_id_str character varying(50),
    contragent_from_id_str character varying(50),
    contragent_to_id_str character varying(50),
    account_id_str character varying(50),
    status_id uuid CONSTRAINT transaction_templates_status_id_not_null NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transaction_templates_created_at_not_null NOT NULL
);


--
-- Name: transaction_templates_20261023_123600 tx_templates_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates_20261023_123600
    ADD CONSTRAINT tx_templates_pkey PRIMARY KEY (id);


--
-- Name: idx_tx_templates_status; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_status ON processing.transaction_templates_20261023_123600 USING btree (status_id);


--
-- Name: transaction_templates_20261023_123600 fk_tx_templates_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates_20261023_123600
    ADD CONSTRAINT fk_tx_templates_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE transaction_templates_20261023_123600; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.transaction_templates_20261023_123600 TO reflex_app_user;
GRANT ALL ON TABLE processing.transaction_templates_20261023_123600 TO receipt_processor_svc;


--
-- PostgreSQL database dump complete
--

\unrestrict OHEaqiDaiLvgWRN5HFh80lBQTqJyGbDErH5QMg3JqGEdPiMc3BdW6JtcOvT2ZA5

