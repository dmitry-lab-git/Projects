--
-- PostgreSQL database dump
--

\restrict hGy4uVKZ7aUlwQMU5H9jlqX5wcd6TujaBVS4mSkMlYcaUrpcl1323DeW318rCSJ

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
-- Name: v_intakes_analysis; Type: VIEW; Schema: medicine; Owner: -
--

CREATE VIEW medicine.v_intakes_analysis AS
 SELECT i.id AS intake_id,
    i.intake_date,
    to_char((i.intake_date)::timestamp with time zone, 'TMDay'::text) AS day_of_week,
    i.supplement_id,
    s.name AS supplement_name,
    s.brand AS supplement_brand,
    s.unit_type,
    i.amount AS units_taken,
    dense_rank() OVER (PARTITION BY i.supplement_id ORDER BY i.intake_date) AS course_day_number,
    sum(i.amount) OVER (PARTITION BY i.supplement_id ORDER BY i.intake_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_total_taken,
    s.is_vegan,
    i.created_at AS logged_at
   FROM (medicine.intakes i
     JOIN medicine.supplements s ON ((i.supplement_id = s.id)));


--
-- Name: TABLE v_intakes_analysis; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.v_intakes_analysis TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict hGy4uVKZ7aUlwQMU5H9jlqX5wcd6TujaBVS4mSkMlYcaUrpcl1323DeW318rCSJ

