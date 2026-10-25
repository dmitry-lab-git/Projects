--
-- PostgreSQL database dump
--

\restrict 4RPUamHovmz8RPLXC7iAKghjXpyhX13Sc5tXKzr1JF7J23hZsp0ZCpeHlKgiKH9

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
-- Name: postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.postings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transaction_id uuid NOT NULL,
    posting_date date NOT NULL,
    debit_account_id uuid NOT NULL,
    credit_account_id uuid NOT NULL,
    amount numeric(15,2) NOT NULL,
    status_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT postings_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: postings postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_pkey PRIMARY KEY (id);


--
-- Name: idx_postings_credit_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_credit_account ON public.postings USING btree (credit_account_id);


--
-- Name: idx_postings_debit_account; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_debit_account ON public.postings USING btree (debit_account_id);


--
-- Name: idx_postings_status_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_status_id ON public.postings USING btree (status_id);


--
-- Name: idx_postings_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postings_transaction_id ON public.postings USING btree (transaction_id);


--
-- Name: postings postings_credit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_credit_account_id_fkey FOREIGN KEY (credit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: postings postings_debit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_debit_account_id_fkey FOREIGN KEY (debit_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: postings postings_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_status_id_fkey FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: postings postings_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id) ON DELETE CASCADE;


--
-- Name: TABLE postings; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.postings TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict 4RPUamHovmz8RPLXC7iAKghjXpyhX13Sc5tXKzr1JF7J23hZsp0ZCpeHlKgiKH9

