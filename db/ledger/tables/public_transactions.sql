--
-- PostgreSQL database dump
--

\restrict tzQJFWPZeb867Sp30eQgfohxACSOi5ChV78oFlLU1OeoRjb5wvQHaBsYtrptYbk

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
-- Name: transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transactions (
    id uuid DEFAULT gen_random_uuid() CONSTRAINT transactions_new_id_not_null NOT NULL,
    code integer CONSTRAINT transactions_new_code_not_null NOT NULL,
    parent_id uuid,
    transaction_name character varying(1024),
    amount numeric(15,2) CONSTRAINT transactions_new_amount_not_null NOT NULL,
    currency_id uuid CONSTRAINT transactions_new_currency_id_not_null NOT NULL,
    operation_date date CONSTRAINT transactions_new_operation_date_not_null NOT NULL,
    operation_time time without time zone,
    registration_date date CONSTRAINT transactions_new_registration_date_not_null NOT NULL,
    type_id uuid CONSTRAINT transactions_new_type_id_not_null NOT NULL,
    entity_id uuid CONSTRAINT transactions_new_entity_id_not_null NOT NULL,
    category_id uuid CONSTRAINT transactions_new_category_id_not_null NOT NULL,
    responsible_id uuid CONSTRAINT transactions_new_responsible_id_not_null NOT NULL,
    contragent_from_id uuid,
    contragent_to_id uuid,
    account_id uuid CONSTRAINT transactions_new_account_id_not_null NOT NULL,
    source_extraction_id uuid CONSTRAINT transactions_new_source_extraction_id_not_null NOT NULL,
    tx_hash character varying(64),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP CONSTRAINT transactions_new_created_at_not_null NOT NULL,
    status_id uuid NOT NULL
);


--
-- Name: transactions_new_code_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.transactions_new_code_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transactions_new_code_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.transactions_new_code_seq OWNED BY public.transactions.code;


--
-- Name: transactions code; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions ALTER COLUMN code SET DEFAULT nextval('public.transactions_new_code_seq'::regclass);


--
-- Name: transactions new_transactions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT new_transactions_code_key UNIQUE (code);


--
-- Name: transactions new_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT new_transactions_pkey PRIMARY KEY (id);


--
-- Name: transactions trg_protect_transactions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_transactions BEFORE DELETE OR UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.protect_existing_transactions();


--
-- Name: transactions fk_transactions_status_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT fk_transactions_status_id FOREIGN KEY (status_id) REFERENCES dicts.dict_statuses(id);


--
-- Name: TABLE transactions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.transactions TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict tzQJFWPZeb867Sp30eQgfohxACSOi5ChV78oFlLU1OeoRjb5wvQHaBsYtrptYbk

