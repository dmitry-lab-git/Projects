--
-- PostgreSQL database dump
--

\restrict sPjsqlevqOViVKQIcdY5uh70dmrCT50G5bhmsBdByUlDOxINHg2KJ9VZn7FmCU9

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

--
-- Name: v_ledger_duck; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_ledger_duck AS
 SELECT transaction_uuid AS "UUID",
    name AS "Название",
    operation_date AS "Дата регистрации",
    amount AS "Сумма"
   FROM public.ledger
  WHERE ((name ~~* '%флис%'::text) OR (name ~~* '%флис%'::text));


--
-- Name: TABLE v_ledger_duck; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.v_ledger_duck TO antigravity;


--
-- PostgreSQL database dump complete
--

\unrestrict sPjsqlevqOViVKQIcdY5uh70dmrCT50G5bhmsBdByUlDOxINHg2KJ9VZn7FmCU9

