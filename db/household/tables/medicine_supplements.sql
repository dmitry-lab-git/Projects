--
-- PostgreSQL database dump
--

\restrict GhSXAXfON1bxaTyh1lYYx0oIBOfglY0rBI02aJ2bXcEc7vbLmCUcvK7wLu41qG2

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
-- Name: supplements; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.supplements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    brand character varying(100),
    unit_type character varying(50) DEFAULT 'таблетка'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description text,
    ingredients text,
    is_vegan boolean DEFAULT false NOT NULL,
    total_quantity integer,
    dosage_per_unit character varying(100),
    expiration_date_months integer
);


--
-- Name: COLUMN supplements.is_vegan; Type: COMMENT; Schema: medicine; Owner: -
--

COMMENT ON COLUMN medicine.supplements.is_vegan IS 'Флаг строго определен: true - подтвержденный веган, false - содержит животные компоненты / не проверен';


--
-- Name: supplements supplements_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.supplements
    ADD CONSTRAINT supplements_pkey PRIMARY KEY (id);


--
-- Name: TABLE supplements; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.supplements TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict GhSXAXfON1bxaTyh1lYYx0oIBOfglY0rBI02aJ2bXcEc7vbLmCUcvK7wLu41qG2

