--
-- PostgreSQL database dump
--

\restrict MI2kg2xWaWeWz7SsxI63UmIVz5aJ3gIggfBM6zxObAsnlbTmVD8PCYTkdXrHfu2

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
-- Name: v_audit_diff; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.v_audit_diff AS
 SELECT t.transaction_id,
    t.category_name AS old_category,
    (s.diff_json ->> 'category_name'::text) AS new_category,
    t.keywords AS old_keywords,
    (s.diff_json ->> 'keywords'::text) AS new_keywords,
    s.reasoning
   FROM (audit.transactions_fullfields t
     JOIN audit.staging_audit_results s ON ((t.transaction_id = s.transaction_id)))
  WHERE (s.is_applied = false);


--
-- Name: TABLE v_audit_diff; Type: ACL; Schema: audit; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE audit.v_audit_diff TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict MI2kg2xWaWeWz7SsxI63UmIVz5aJ3gIggfBM6zxObAsnlbTmVD8PCYTkdXrHfu2

