--
-- PostgreSQL database dump
--

\restrict ou0AzuNnU2e3EcifKJDvTl8ZGwIagvPsMD0RPQidghViyZJXcssfniRLcT74HFg

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
-- Name: posting_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posting_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_name character varying(100),
    type_name character varying(100),
    account_name character varying(100),
    debit_account_id uuid NOT NULL,
    credit_account_id uuid NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: posting_rules posting_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_pkey PRIMARY KEY (id);


--
-- Name: idx_posting_rules_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posting_rules_status_id ON public.posting_rules USING btree (status_id);


--
-- Name: posting_rules posting_rules_credit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_credit_account_id_fkey FOREIGN KEY (credit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: posting_rules posting_rules_debit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_debit_account_id_fkey FOREIGN KEY (debit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: posting_rules posting_rules_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posting_rules
    ADD CONSTRAINT posting_rules_status_id_fkey FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE posting_rules; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.posting_rules TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict ou0AzuNnU2e3EcifKJDvTl8ZGwIagvPsMD0RPQidghViyZJXcssfniRLcT74HFg

