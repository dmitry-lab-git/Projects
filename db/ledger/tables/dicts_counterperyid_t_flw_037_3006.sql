--
-- PostgreSQL database dump
--

\restrict RLiLNPwgP7f8mnu1Kxaf4P9H9hIgr1ev54YTvLzl8vcYEQiHFxyR1uZaVqXeyJW

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
-- Name: counterperyid_t_flw_037_3006; Type: TABLE; Schema: dicts; Owner: -
--

CREATE TABLE dicts.counterperyid_t_flw_037_3006 (
    "Seq" integer,
    "CounterpartyName" text,
    "CtrCode" integer,
    "CtrID" character varying(50),
    "Type" character varying(50),
    "Status" character varying(50),
    "CreatedAt" character varying(50),
    "ObservedAt" character varying(50),
    "Описание" text,
    "Адрес" character varying(64),
    "Телефон" character varying(50),
    "Комментарий" text
);


--
-- Name: TABLE counterperyid_t_flw_037_3006; Type: ACL; Schema: dicts; Owner: -
--

GRANT SELECT ON TABLE dicts.counterperyid_t_flw_037_3006 TO receipt_processor_svc;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE dicts.counterperyid_t_flw_037_3006 TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict RLiLNPwgP7f8mnu1Kxaf4P9H9hIgr1ev54YTvLzl8vcYEQiHFxyR1uZaVqXeyJW

