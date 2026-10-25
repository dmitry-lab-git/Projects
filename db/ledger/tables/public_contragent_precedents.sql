--
-- PostgreSQL database dump
--

\restrict FqiLkD7MpBwii80VuwIdUebl81f5s0ml7kyj7G6QEppQxpgQoxrq265dhUP0tTZ

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
-- Name: contragent_precedents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contragent_precedents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contragent_id uuid NOT NULL,
    status_id uuid NOT NULL,
    branch_type character varying(30) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_precedent_branch_type CHECK (((branch_type)::text = ANY ((ARRAY['informative'::character varying, 'workflow'::character varying])::text[])))
);


--
-- Name: contragent_precedents contragent_precedents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contragent_precedents
    ADD CONSTRAINT contragent_precedents_pkey PRIMARY KEY (id);


--
-- Name: idx_precedents_branch_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_precedents_branch_status ON public.contragent_precedents USING btree (branch_type, status_id);


--
-- Name: idx_precedents_contragent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_precedents_contragent ON public.contragent_precedents USING btree (contragent_id);


--
-- Name: contragent_precedents fk_contragent_precedents_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contragent_precedents
    ADD CONSTRAINT fk_contragent_precedents_status FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE contragent_precedents; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.contragent_precedents TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict FqiLkD7MpBwii80VuwIdUebl81f5s0ml7kyj7G6QEppQxpgQoxrq265dhUP0tTZ

