--
-- PostgreSQL database dump
--

\restrict iPm99YLAzHed4bAs59tQHy1SbTnJnFROq7Ihwx0Adi2d5JWV2JY1qpxx4yiVbKM

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
-- Name: external_services; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.external_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_type character varying(100) NOT NULL,
    description text NOT NULL,
    contractor_name character varying(255),
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT external_services_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: external_services external_services_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.external_services
    ADD CONSTRAINT external_services_pkey PRIMARY KEY (id);


--
-- Name: idx_external_services_lookup; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_external_services_lookup ON texere.external_services USING btree (service_type, contractor_name);


--
-- Name: idx_external_services_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_external_services_tx_code ON texere.external_services USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- PostgreSQL database dump complete
--

\unrestrict iPm99YLAzHed4bAs59tQHy1SbTnJnFROq7Ihwx0Adi2d5JWV2JY1qpxx4yiVbKM

