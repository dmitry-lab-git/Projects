--
-- PostgreSQL database dump
--

\restrict jDfoyzwBMF3pQT7WTUs0Kk0KqP1hQM4GVsGKPnBR5yYtEK6ZXUXcQhuWQvfQvLh

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
-- Name: source_extractions; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.source_extractions (
    id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    description text
);


--
-- Name: source_extractions source_extractions_pkey; Type: CONSTRAINT; Schema: dicts; Owner: -
--

ALTER TABLE ONLY dicts.source_extractions
    ADD CONSTRAINT source_extractions_pkey PRIMARY KEY (id);


--
-- Name: TABLE source_extractions; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.source_extractions TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.source_extractions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict jDfoyzwBMF3pQT7WTUs0Kk0KqP1hQM4GVsGKPnBR5yYtEK6ZXUXcQhuWQvfQvLh

