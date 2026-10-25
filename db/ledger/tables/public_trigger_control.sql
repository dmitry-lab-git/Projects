--
-- PostgreSQL database dump
--

\restrict 1KhzLW2WUBEqsf2BgtC2vn933jlKf9ndqMfywLP4vj0gD2gy5mDObH4oMhtDkLt

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
-- Name: trigger_control; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trigger_control (
    trigger_name text NOT NULL,
    is_enabled boolean DEFAULT true,
    description text,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: trigger_control trigger_control_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trigger_control
    ADD CONSTRAINT trigger_control_pkey PRIMARY KEY (trigger_name);


--
-- Name: TABLE trigger_control; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.trigger_control TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict 1KhzLW2WUBEqsf2BgtC2vn933jlKf9ndqMfywLP4vj0gD2gy5mDObH4oMhtDkLt

