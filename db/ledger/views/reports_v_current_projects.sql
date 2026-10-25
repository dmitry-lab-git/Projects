--
-- PostgreSQL database dump
--

\restrict E889GH9QGmapfkRc1UvLyJqsK8xzWj1TeeyKEkeyyLE3quVjAmKmo8blfhxUOZb

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
-- Name: v_current_projects; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.v_current_projects AS
 SELECT p.id AS project_id,
    p.slug,
    s.code AS status_code,
    s.name AS status_name,
    p.created_at
   FROM (projects.registry p
     JOIN dicts.dict_statuses s ON ((p.status_id = s.id)))
  WHERE (((s.entity_type)::text = 'PROJECT'::text) AND ((s.code)::text = ANY ((ARRAY['DRAFT'::character varying, 'QUEUED'::character varying, 'DEVELOPMENT'::character varying, 'ACTIVE'::character varying])::text[])))
  ORDER BY p.created_at DESC;


--
-- Name: TABLE v_current_projects; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.v_current_projects TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict E889GH9QGmapfkRc1UvLyJqsK8xzWj1TeeyKEkeyyLE3quVjAmKmo8blfhxUOZb

