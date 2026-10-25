--
-- PostgreSQL database dump
--

\restrict E5fwqkrY4R7frcFLWbVAH5vDnJWF4pdjBzcnW1JWQAKYKQTZzztY80CfkY5JjMf

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
-- Name: consumables_inventory; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.consumables_inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    consumable_type character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    merchant_name character varying(255),
    unit character varying(20) DEFAULT 'шт'::character varying NOT NULL,
    initial_quantity numeric(10,3) NOT NULL,
    current_balance numeric(10,3) NOT NULL,
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    price_per_unit numeric(12,2) GENERATED ALWAYS AS (
CASE
    WHEN (initial_quantity > (0)::numeric) THEN (total_cost_kzt / initial_quantity)
    ELSE 0.00
END) STORED,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_consumables_balance_limit CHECK ((current_balance <= initial_quantity)),
    CONSTRAINT consumables_inventory_current_balance_check CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT consumables_inventory_initial_quantity_check CHECK ((initial_quantity >= (0)::numeric)),
    CONSTRAINT consumables_inventory_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: consumables_inventory consumables_inventory_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.consumables_inventory
    ADD CONSTRAINT consumables_inventory_pkey PRIMARY KEY (id);


--
-- Name: idx_consumables_inv_active_balance; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_active_balance ON texere.consumables_inventory USING btree (current_balance) WHERE (current_balance > (0)::numeric);


--
-- Name: idx_consumables_inv_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_tx_code ON texere.consumables_inventory USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_consumables_inv_tx_link; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_tx_link ON texere.consumables_inventory USING btree (transaction_uuid) WHERE (transaction_uuid IS NOT NULL);


--
-- Name: idx_consumables_inv_type_name; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_type_name ON texere.consumables_inventory USING btree (consumable_type, name);


--
-- PostgreSQL database dump complete
--

\unrestrict E5fwqkrY4R7frcFLWbVAH5vDnJWF4pdjBzcnW1JWQAKYKQTZzztY80CfkY5JjMf

