--
-- PostgreSQL database dump
--

\restrict kX1OdUOIjd1NNcXiYPP62x4a6ampB1dQrFpfi5UU6PPcdeBBuoRjkS8TdWd37j0

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
-- Name: intakes; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.intakes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    intake_date date NOT NULL,
    supplement_id uuid NOT NULL,
    amount integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: intakes intakes_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.intakes
    ADD CONSTRAINT intakes_pkey PRIMARY KEY (id);


--
-- Name: intakes trg_biu_check_daily_supplement_limit; Type: TRIGGER; Schema: medicine; Owner: -
--

CREATE TRIGGER trg_biu_check_daily_supplement_limit BEFORE INSERT OR UPDATE ON medicine.intakes FOR EACH ROW EXECUTE FUNCTION medicine.fn_check_daily_supplement_limit();


--
-- Name: intakes intakes_supplement_id_fkey; Type: FK CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.intakes
    ADD CONSTRAINT intakes_supplement_id_fkey FOREIGN KEY (supplement_id) REFERENCES medicine.supplements(id) ON DELETE CASCADE;


--
-- Name: TABLE intakes; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.intakes TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict kX1OdUOIjd1NNcXiYPP62x4a6ampB1dQrFpfi5UU6PPcdeBBuoRjkS8TdWd37j0

