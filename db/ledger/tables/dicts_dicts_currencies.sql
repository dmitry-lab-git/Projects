--
-- PostgreSQL database dump
--

\restrict 0CvhMeZaJs9VvQ4TUQuM8ee0PypsvYfS1a1pc6PD1wOU8MtplXQyPt8pwIe3tT2

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
-- Name: dicts_currencies; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.dicts_currencies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    currency_id character varying(10) CONSTRAINT dicts_currencies_code_not_null NOT NULL,
    code integer
);


--
-- Name: dicts_currencies dicts_currencies_code_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dicts_currencies
    ADD CONSTRAINT dicts_currencies_code_key UNIQUE (code);


--
-- Name: dicts_currencies dicts_currencies_id_key; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dicts_currencies
    ADD CONSTRAINT dicts_currencies_id_key UNIQUE (currency_id);


--
-- Name: dicts_currencies dicts_currencies_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.dicts_currencies
    ADD CONSTRAINT dicts_currencies_pkey PRIMARY KEY (id);


--
-- Name: TABLE dicts_currencies; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.dicts_currencies TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.dicts_currencies TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict 0CvhMeZaJs9VvQ4TUQuM8ee0PypsvYfS1a1pc6PD1wOU8MtplXQyPt8pwIe3tT2

