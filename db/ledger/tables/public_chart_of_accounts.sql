--
-- PostgreSQL database dump
--

\restrict hYCVGzBOjnsGm3SF2IsZ8o25WZFgauCldAsGTU9xdojSl9iryCnodVCa82DWiRX

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
-- Name: chart_of_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chart_of_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_code character varying(20) NOT NULL,
    account_name character varying(500) NOT NULL,
    parent_id uuid,
    is_reconciliation boolean DEFAULT false NOT NULL,
    account_class character varying(50) NOT NULL,
    normal_balance character varying(10) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT coa_account_class_check CHECK (((account_class)::text = ANY ((ARRAY['ASSET'::character varying, 'LIABILITY'::character varying, 'EQUITY'::character varying, 'REVENUE'::character varying, 'EXPENSE'::character varying])::text[]))),
    CONSTRAINT coa_normal_balance_check CHECK (((normal_balance)::text = ANY ((ARRAY['DEBIT'::character varying, 'CREDIT'::character varying])::text[])))
);


--
-- Name: chart_of_accounts coa_account_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT coa_account_code_key UNIQUE (account_code);


--
-- Name: chart_of_accounts coa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT coa_pkey PRIMARY KEY (id);


--
-- Name: idx_coa_code_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_coa_code_lookup ON public.chart_of_accounts USING btree (account_code);


--
-- Name: chart_of_accounts fk_coa_parent; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT fk_coa_parent FOREIGN KEY (parent_id) REFERENCES public.chart_of_accounts(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: TABLE chart_of_accounts; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.chart_of_accounts TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict hYCVGzBOjnsGm3SF2IsZ8o25WZFgauCldAsGTU9xdojSl9iryCnodVCa82DWiRX

