--
-- PostgreSQL database dump
--

\restrict qRmKBKE2TYApXkfU1RGbBdNhEhbq21nJogm4MzZEF2ve1CROGQ2INcVyd2hZXW3

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
-- Name: nodes; Type: TABLE; Schema: kernel; Owner: -
--

CREATE TABLE kernel.nodes (
    node_id integer NOT NULL,
    entity_code text NOT NULL,
    entity_type text NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb
);


--
-- Name: nodes_node_id_seq; Type: SEQUENCE; Schema: kernel; Owner: -
--

CREATE SEQUENCE kernel.nodes_node_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nodes_node_id_seq; Type: SEQUENCE OWNED BY; Schema: kernel; Owner: -
--

ALTER SEQUENCE kernel.nodes_node_id_seq OWNED BY kernel.nodes.node_id;


--
-- Name: nodes node_id; Type: DEFAULT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.nodes ALTER COLUMN node_id SET DEFAULT nextval('kernel.nodes_node_id_seq'::regclass);


--
-- Name: nodes nodes_entity_code_key; Type: CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.nodes
    ADD CONSTRAINT nodes_entity_code_key UNIQUE (entity_code);


--
-- Name: nodes nodes_pkey; Type: CONSTRAINT; Schema: kernel; Owner: -
--

ALTER TABLE ONLY kernel.nodes
    ADD CONSTRAINT nodes_pkey PRIMARY KEY (node_id);


--
-- Name: idx_nodes_entity_code; Type: INDEX; Schema: kernel; Owner: -
--

CREATE INDEX idx_nodes_entity_code ON kernel.nodes USING btree (entity_code);


--
-- PostgreSQL database dump complete
--

\unrestrict qRmKBKE2TYApXkfU1RGbBdNhEhbq21nJogm4MzZEF2ve1CROGQ2INcVyd2hZXW3

