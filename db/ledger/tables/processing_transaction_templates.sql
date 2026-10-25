--
-- PostgreSQL database dump
--

\restrict Lbhfel95Ks15R9fLDvD0NYFJhMOJTeAH69KHYCYGTrMZFGAo0rJjcFtffa9UQBT

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
-- Name: transaction_templates; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.transaction_templates (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transaction_templates_id_not_null1 NOT NULL,
    transaction_name character varying(150) CONSTRAINT transaction_templates_transaction_name_not_null1 NOT NULL,
    amount numeric(15,2),
    currency_id uuid,
    type_id uuid,
    entity_id uuid,
    category_id uuid,
    responsible_id uuid,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid,
    status_id uuid CONSTRAINT transaction_templates_status_id_not_null1 NOT NULL,
    created_at timestamp(6) with time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transaction_templates_created_at_not_null1 NOT NULL
);


--
-- Name: transaction_templates tx_templates_v11_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT tx_templates_v11_pkey PRIMARY KEY (id);


--
-- Name: idx_tx_templates_v11_account; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_v11_account ON processing.transaction_templates USING btree (account_id);


--
-- Name: idx_tx_templates_v11_entity; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_v11_entity ON processing.transaction_templates USING btree (entity_id);


--
-- Name: idx_tx_templates_v11_status; Type: INDEX; Schema: processing; Owner: -
--

CREATE INDEX idx_tx_templates_v11_status ON processing.transaction_templates USING btree (status_id);


--
-- Name: transaction_templates fk_tx_templates_account; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_account FOREIGN KEY (account_id) REFERENCES dicts.accounts(id);


--
-- Name: transaction_templates fk_tx_templates_category; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_category FOREIGN KEY (category_id) REFERENCES dicts.dict_categories(id);


--
-- Name: transaction_templates fk_tx_templates_contragent_from; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_contragent_from FOREIGN KEY (contragent_from_id) REFERENCES dicts.contragents(id);


--
-- Name: transaction_templates fk_tx_templates_contragent_to; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_contragent_to FOREIGN KEY (contragent_to_id) REFERENCES dicts.contragents(id);


--
-- Name: transaction_templates fk_tx_templates_currency; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_currency FOREIGN KEY (currency_id) REFERENCES dicts.dicts_currencies(id);


--
-- Name: transaction_templates fk_tx_templates_entity; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_entity FOREIGN KEY (entity_id) REFERENCES dicts.entities(id);


--
-- Name: transaction_templates fk_tx_templates_responsible; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_responsible FOREIGN KEY (responsible_id) REFERENCES dicts.responsibles(id);


--
-- Name: transaction_templates fk_tx_templates_status; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: transaction_templates fk_tx_templates_type; Type: FK CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.transaction_templates
    ADD CONSTRAINT fk_tx_templates_type FOREIGN KEY (type_id) REFERENCES dicts.dict_types(id);


--
-- Name: TABLE transaction_templates; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.transaction_templates TO reflex_app_user;
GRANT ALL ON TABLE processing.transaction_templates TO receipt_processor_svc;


--
-- PostgreSQL database dump complete
--

\unrestrict Lbhfel95Ks15R9fLDvD0NYFJhMOJTeAH69KHYCYGTrMZFGAo0rJjcFtffa9UQBT

