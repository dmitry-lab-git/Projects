--
-- PostgreSQL database dump
--

\restrict YxJkdpc09DI7joA5DxBloZwObaQF9jVozyv1SfRnq077T2Xsh5UKvlz2BXamfXG

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
-- Name: support_tickets; Type: TABLE; Schema: development; Owner: -
--

CREATE TABLE development.support_tickets (
    id integer NOT NULL,
    project_id character varying(50),
    ticket_reference character varying(100),
    issue_type character varying(50),
    status character varying(20),
    attachments_path character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    comment text,
    ticket_uuid uuid DEFAULT gen_random_uuid()
);


--
-- Name: support_tickets_id_seq; Type: SEQUENCE; Schema: development; Owner: -
--

CREATE SEQUENCE development.support_tickets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: support_tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: development; Owner: -
--

ALTER SEQUENCE development.support_tickets_id_seq OWNED BY development.support_tickets.id;


--
-- Name: support_tickets id; Type: DEFAULT; Schema: development; Owner: -
--

ALTER TABLE ONLY development.support_tickets ALTER COLUMN id SET DEFAULT nextval('development.support_tickets_id_seq'::regclass);


--
-- Name: support_tickets support_tickets_pkey; Type: CONSTRAINT; Schema: development; Owner: -
--

ALTER TABLE ONLY development.support_tickets
    ADD CONSTRAINT support_tickets_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict YxJkdpc09DI7joA5DxBloZwObaQF9jVozyv1SfRnq077T2Xsh5UKvlz2BXamfXG

