--
-- PostgreSQL database dump
--

\restrict hB5mCm3dHs7DOV7yoVFG9gQoCG6eY5lqnBGdhu7912ge25c0LCIVwJnGC2vRfa5

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
-- Name: v_monthly_supplements_summary; Type: VIEW; Schema: medicine; Owner: -
--

CREATE VIEW medicine.v_monthly_supplements_summary AS
 SELECT s.name AS supplement_name,
    s.brand AS supplement_brand,
    s.unit_type,
    count(DISTINCT i.intake_date) AS days_taken_count,
    sum(i.amount) AS total_units_taken,
    round(avg(i.amount), 2) AS avg_daily_dosage,
    min(i.intake_date) AS first_intake_in_period,
    max(i.intake_date) AS last_intake_in_period
   FROM (medicine.intakes i
     JOIN medicine.supplements s ON ((i.supplement_id = s.id)))
  WHERE (i.intake_date >= (CURRENT_DATE - '1 mon'::interval))
  GROUP BY s.id, s.name, s.brand, s.unit_type;


--
-- Name: TABLE v_monthly_supplements_summary; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.v_monthly_supplements_summary TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict hB5mCm3dHs7DOV7yoVFG9gQoCG6eY5lqnBGdhu7912ge25c0LCIVwJnGC2vRfa5

