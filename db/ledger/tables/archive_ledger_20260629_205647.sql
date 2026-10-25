--
-- PostgreSQL database dump
--

\restrict jzcbiJVELaGC0gkXOj2YUExgiXLpYPHXqvnIf2Wycxbqn0zFopOWGBKcDLN2Ld9

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
-- Name: ledger_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.ledger_20260629_205647 (
    transaction_id integer,
    name character varying(512),
    operation_date date,
    category_id character varying(50),
    amount numeric(19,4),
    type_id character varying(50),
    contragent_from_id character varying(50),
    contragent_to_id character varying(50),
    prev_acc_tr_id integer,
    prev_acc_tr_balance numeric(19,4),
    acc_balance numeric(19,4),
    system_balance numeric(19,4),
    check_sum character varying(64),
    is_verified boolean,
    account_id character varying(50),
    manual_acc_balance numeric(19,4),
    diff numeric(19,4),
    transaction_uuid uuid
);


--
-- PostgreSQL database dump complete
--

\unrestrict jzcbiJVELaGC0gkXOj2YUExgiXLpYPHXqvnIf2Wycxbqn0zFopOWGBKcDLN2Ld9

