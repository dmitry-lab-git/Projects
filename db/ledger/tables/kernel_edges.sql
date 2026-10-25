--
-- PostgreSQL database dump
--

\restrict Nnt8PQjSOwyWKujaE4IDEjkVFpowbQeRxi0xxwa6PWORbP0PLEOtuiKXGNQ4nYs

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
-- Name: edges; Type: TABLE; Schema: kernel; Owner: -
--

CREATE TABLE kernel.edges (
    edge_id integer NOT NULL,
    source_node_id integer NOT NULL,
    target_node_id integer NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb
);


--
-- Name: edges_edge_id_seq; Type: SEQUENCE; Schema: kernel; Owner: -
--

CREATE SEQUENCE kernel.edges_edge_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: edges_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: kernel; Owner: -
--

ALTER SEQUENCE kernel.edges_edge_id_seq OWNED BY kernel.edges.edge_id;


--
-- Name: edges edge_id; Type: DEFAULT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges ALTER COLUMN edge_id SET DEFAULT nextval('kernel.edges_edge_id_seq'::regclass);


--
-- Name: edges edges_pkey; Type: CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges
    ADD CONSTRAINT edges_pkey PRIMARY KEY (edge_id);


--
-- Name: idx_edges_source_node; Type: INDEX; Schema: kernel; Owner: -
--

CREATE INDEX idx_edges_source_node ON kernel.edges USING btree (source_node_id);


--
-- Name: idx_edges_target_node; Type: INDEX; Schema: kernel; Owner: -
--

CREATE INDEX idx_edges_target_node ON kernel.edges USING btree (target_node_id);


--
-- Name: edges edges_source_node_id_fkey; Type: FK CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges
    ADD CONSTRAINT edges_source_node_id_fkey FOREIGN KEY (source_node_id) REFERENCES kernel.nodes(node_id) ON DELETE CASCADE;


--
-- Name: edges edges_target_node_id_fkey; Type: FK CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.edges
    ADD CONSTRAINT edges_target_node_id_fkey FOREIGN KEY (target_node_id) REFERENCES kernel.nodes(node_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict Nnt8PQjSOwyWKujaE4IDEjkVFpowbQeRxi0xxwa6PWORbP0PLEOtuiKXGNQ4nYs

