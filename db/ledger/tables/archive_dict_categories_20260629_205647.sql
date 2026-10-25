--
-- PostgreSQL database dump
--

\restrict Idhe1pbwdFukq5uSiGTSIYbq48D8PWheITf1dMjNqNkPAaBOCtnzRCUJg1f92Rb

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
-- Name: dict_categories_20260629_205647; Type: TABLE; Schema: archive; Owner: -
--

CREATE TABLE archive.dict_categories_20260629_205647 (
    code integer,
    category_name character varying(255),
    category_id character varying(50),
    parent_category_id character varying(50),
    keywords text[],
    created_at timestamp with time zone,
    id uuid,
    status_id uuid
);


--
-- PostgreSQL database dump complete
--

\unrestrict Idhe1pbwdFukq5uSiGTSIYbq48D8PWheITf1dMjNqNkPAaBOCtnzRCUJg1f92Rb

