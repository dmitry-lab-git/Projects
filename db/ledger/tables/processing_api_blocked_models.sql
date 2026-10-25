--
-- PostgreSQL database dump
--

\restrict C11ZsehgFdzUbAHB8tBn6txWEOBwUBw8Vw5VlydfGkBYpHTss56ppDc3gRQIprJ

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
-- Name: api_blocked_models; Type: TABLE; Schema: processing; Owner: -
--

CREATE TABLE processing.api_blocked_models (
    model_name text NOT NULL,
    blocked_until timestamp with time zone NOT NULL
);


--
-- Name: api_blocked_models api_blocked_models_pkey; Type: CONSTRAINT; Schema: processing; Owner: -
--

ALTER TABLE ONLY processing.api_blocked_models
    ADD CONSTRAINT api_blocked_models_pkey PRIMARY KEY (model_name);


--
-- Name: TABLE api_blocked_models; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.api_blocked_models TO receipt_processor_svc;
GRANT ALL ON TABLE processing.api_blocked_models TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict C11ZsehgFdzUbAHB8tBn6txWEOBwUBw8Vw5VlydfGkBYpHTss56ppDc3gRQIprJ

