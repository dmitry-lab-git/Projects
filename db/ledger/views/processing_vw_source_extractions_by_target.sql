--
-- PostgreSQL database dump
--

\restrict lHTMetLr0BCtfReKDLfX6EOveihWA6xVGTsafCvYldqUsMQEJsDkwKNdjwvpYYP

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
-- Name: vw_source_extractions_by_target; Type: VIEW; Schema: processing; Owner: -
--

CREATE VIEW processing.vw_source_extractions_by_target AS
 SELECT target_name,
    count(*) AS extractions_count
   FROM processing.source_extractions
  GROUP BY target_name
  ORDER BY (count(*)) DESC;


--
-- Name: TABLE vw_source_extractions_by_target; Type: ACL; Schema: processing; Owner: -
--

GRANT ALL ON TABLE processing.vw_source_extractions_by_target TO receipt_processor_svc;
GRANT ALL ON TABLE processing.vw_source_extractions_by_target TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict lHTMetLr0BCtfReKDLfX6EOveihWA6xVGTsafCvYldqUsMQEJsDkwKNdjwvpYYP

