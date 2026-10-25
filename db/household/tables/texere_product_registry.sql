--
-- PostgreSQL database dump
--

\restrict jSqFUSKd4oO2kt3WQjElIwAUdzlOBEmV045b14cFSG8yPo4fPvpypMSZOpO85kY

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
-- Name: product_registry; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.product_registry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(255) NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    materials jsonb DEFAULT '{}'::jsonb NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    completion_date date,
    quality_rating integer,
    comments text,
    original_photo character varying(2048),
    processed_photo character varying(2048),
    is_published boolean DEFAULT false NOT NULL,
    project_cost_kzt numeric(12,2),
    CONSTRAINT chk_quality_range CHECK (((quality_rating >= 1) AND (quality_rating <= 10)))
);


--
-- Name: product_registry product_registry_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.product_registry
    ADD CONSTRAINT product_registry_pkey PRIMARY KEY (id);


--
-- Name: idx_product_registry_completion_date; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_completion_date ON texere.product_registry USING btree (completion_date);


--
-- Name: idx_product_registry_materials; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_materials ON texere.product_registry USING gin (materials);


--
-- Name: idx_product_registry_meta; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_meta ON texere.product_registry USING gin (meta);


--
-- Name: idx_product_registry_project_cost; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_project_cost ON texere.product_registry USING btree (project_cost_kzt);


--
-- PostgreSQL database dump complete
--

\unrestrict jSqFUSKd4oO2kt3WQjElIwAUdzlOBEmV045b14cFSG8yPo4fPvpypMSZOpO85kY

