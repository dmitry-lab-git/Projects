--
-- PostgreSQL database dump
--

\restrict p9czOj5i2tbbiUlGj3crWLvfuBFjDNQG7GSHk5iVNdyrLofnZxOpVlVSkkZl9uh

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
-- Name: unreconciled_transactions; Type: VIEW; Schema: texere; Owner: -
--

CREATE VIEW texere.unreconciled_transactions AS
 SELECT tx_date,
    tx_code,
    merchant,
    amount,
    description,
    uuid2
   FROM texere.raw_transactions t
  WHERE (NOT (EXISTS ( SELECT 1
           FROM texere.materials_inventory m
          WHERE ((m.transaction_uuid = t.uuid2) OR (m.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.consumables_inventory c
          WHERE ((c.transaction_uuid = t.uuid2) OR (c.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.patterns_inventory p
          WHERE ((p.transaction_uuid = t.uuid2) OR (p.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.tools_inventory tool
          WHERE ((tool.transaction_uuid = t.uuid2) OR (tool.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.external_services s
          WHERE ((s.transaction_uuid = t.uuid2) OR (s.tx_code = t.tx_code)))));


--
-- PostgreSQL database dump complete
--

\unrestrict p9czOj5i2tbbiUlGj3crWLvfuBFjDNQG7GSHk5iVNdyrLofnZxOpVlVSkkZl9uh

