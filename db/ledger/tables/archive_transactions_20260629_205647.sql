--
-- PostgreSQL database dump
--

\restrict ejR9RpYrRkSg0IgZAQEvX9VxYOg486pvyspI84sGB9OKbq1Uo3rc3gDVxUFAefk

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
-- Name: transactions_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.transactions_20260629_205647 (
    code integer,
    legacy_code integer,
    transaction_name character varying(512),
    entity_id character varying(50),
    registration_date date,
    operation_date date,
    transaction_id character varying(50),
    category_id character varying(50),
    responsible_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    account_id character varying(50),
    type_id character varying(50),
    amount numeric(15,2),
    tr_currency character varying(50),
    id uuid,
    parent_id uuid,
    tx_hash character varying(64),
    created_at timestamp without time zone,
    operation_time time without time zone,
    source_extraction_id uuid
);


--
-- PostgreSQL database dump complete
--

\unrestrict ejR9RpYrRkSg0IgZAQEvX9VxYOg486pvyspI84sGB9OKbq1Uo3rc3gDVxUFAefk

