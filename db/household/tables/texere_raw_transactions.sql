--
-- PostgreSQL database dump
--

\restrict h07qdy7qM2iie2GsBoF5aLirOKXRgmVYriIfbee7xMauDXg1YvSIaNBrOQu7dEZ

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
-- Name: raw_transactions; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.raw_transactions (
    tx_date date,
    tx_code integer,
    merchant character varying(255),
    status_desc character varying(100),
    status character varying(50),
    category character varying(100),
    description text,
    amount numeric(12,2),
    project character varying(255),
    uuid1 uuid,
    uuid2 uuid,
    uuid3 uuid,
    uuid4 uuid
);


--
-- PostgreSQL database dump complete
--

\unrestrict h07qdy7qM2iie2GsBoF5aLirOKXRgmVYriIfbee7xMauDXg1YvSIaNBrOQu7dEZ

