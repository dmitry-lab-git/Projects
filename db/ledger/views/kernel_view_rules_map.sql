--
-- PostgreSQL database dump
--

\restrict Ym7aOZYg1qR1WdG9wRVaIkre8BfP1h0A38HPerYqlRlXhQyjrKFYdgO7N4chHDe

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

--
-- Name: view_rules_map; Type: VIEW; Schema: kernel; Owner: -
--

CREATE VIEW kernel.view_rules_map AS
 SELECT source.entity_code AS operation,
    target.entity_code AS target_entity,
    (e.meta ->> 'check'::text) AS rule_type,
    n.entity_type AS target_type
   FROM (((kernel.edges e
     JOIN kernel.nodes source ON ((e.source_node_id = source.node_id)))
     JOIN kernel.nodes target ON ((e.target_node_id = target.node_id)))
     JOIN kernel.nodes n ON ((e.target_node_id = n.node_id)))
  ORDER BY source.entity_code;


--
-- PostgreSQL database dump complete
--

\unrestrict Ym7aOZYg1qR1WdG9wRVaIkre8BfP1h0A38HPerYqlRlXhQyjrKFYdgO7N4chHDe

