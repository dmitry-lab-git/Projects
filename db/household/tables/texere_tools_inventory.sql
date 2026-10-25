--
-- PostgreSQL database dump
--

\restrict KhSbbKwvf8WJNuZRNtFTHLdfmU860NsNJXcZLhwiej3Of6oHbBQr07hQ4q8CGrG

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
-- Name: tools_inventory; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.tools_inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tool_type character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    merchant_name character varying(255),
    unit character varying(20) DEFAULT 'шт'::character varying NOT NULL,
    initial_quantity numeric(10,3) NOT NULL,
    scrapped_quantity numeric(10,3) DEFAULT 0.000 NOT NULL,
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    price_per_unit numeric(12,2) GENERATED ALWAYS AS (
CASE
    WHEN (initial_quantity > (0)::numeric) THEN (total_cost_kzt / initial_quantity)
    ELSE 0.00
END) STORED,
    condition_status character varying(100) DEFAULT 'В работе'::character varying,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_tools_scrapped_limit CHECK ((scrapped_quantity <= initial_quantity)),
    CONSTRAINT tools_inventory_initial_quantity_check CHECK ((initial_quantity >= (0)::numeric)),
    CONSTRAINT tools_inventory_scrapped_quantity_check CHECK ((scrapped_quantity >= (0)::numeric)),
    CONSTRAINT tools_inventory_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: tools_inventory tools_inventory_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.tools_inventory
    ADD CONSTRAINT tools_inventory_pkey PRIMARY KEY (id);


--
-- Name: idx_tools_inv_active; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_active ON texere.tools_inventory USING btree (initial_quantity) WHERE (initial_quantity > scrapped_quantity);


--
-- Name: idx_tools_inv_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_tx_code ON texere.tools_inventory USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_tools_inv_tx_link; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_tx_link ON texere.tools_inventory USING btree (transaction_uuid) WHERE (transaction_uuid IS NOT NULL);


--
-- Name: idx_tools_inv_type_name; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_type_name ON texere.tools_inventory USING btree (tool_type, name);


--
-- PostgreSQL database dump complete
--

\unrestrict KhSbbKwvf8WJNuZRNtFTHLdfmU860NsNJXcZLhwiej3Of6oHbBQr07hQ4q8CGrG

