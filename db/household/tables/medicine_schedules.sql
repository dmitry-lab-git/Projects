--
-- PostgreSQL database dump
--

\restrict Ib6jxcyMbcfop7ab7DGptYS0ZKZlkQ6qmLeabqU6vGpb7ZmL7DSwTdmkfv7B8M8

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
-- Name: schedules; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    supplement_id uuid NOT NULL,
    start_date date NOT NULL,
    end_date date,
    target_daily_amount integer NOT NULL,
    frequency_per_day integer DEFAULT 1 NOT NULL,
    notification_times time without time zone[] DEFAULT '{}'::time without time zone[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status medicine.schedule_status DEFAULT 'active'::medicine.schedule_status NOT NULL,
    CONSTRAINT check_dates CHECK (((end_date IS NULL) OR (end_date >= start_date))),
    CONSTRAINT check_positive_amount CHECK ((target_daily_amount > 0)),
    CONSTRAINT check_positive_frequency CHECK ((frequency_per_day > 0))
);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_supplement_id_fkey; Type: FK CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.schedules
    ADD CONSTRAINT schedules_supplement_id_fkey FOREIGN KEY (supplement_id) REFERENCES medicine.supplements(id) ON DELETE CASCADE;


--
-- Name: TABLE schedules; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.schedules TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict Ib6jxcyMbcfop7ab7DGptYS0ZKZlkQ6qmLeabqU6vGpb7ZmL7DSwTdmkfv7B8M8

