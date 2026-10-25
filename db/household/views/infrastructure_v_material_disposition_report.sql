--
-- PostgreSQL database dump
--

\restrict wEWyVcPhahDgzfaADojDZC7Q4cpr36cpb0Lbbzv3cZAxLer0dl4jt8MncncUzn7

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
-- Name: v_material_disposition_report; Type: VIEW; Schema: infrastructure; Owner: -
--

CREATE VIEW infrastructure.v_material_disposition_report AS
 SELECT rc.material_name AS resource_name,
    rc.resource_type,
    rc.default_unit AS unit,
    mdv.device_name,
    mdv.uncertainty,
    md.quantity,
    md.utilized_at,
    md.created_at,
    dp.name AS disposal_point_name,
    dp.type AS disposal_point_type
   FROM (((infrastructure.material_disposition md
     JOIN infrastructure.resource_catalog rc ON ((md.resource_id = rc.id)))
     LEFT JOIN infrastructure.measuring_devices mdv ON ((md.device_id = mdv.id)))
     LEFT JOIN infrastructure.disposal_points dp ON ((md.disposal_point = dp.id)));


--
-- Name: TABLE v_material_disposition_report; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.v_material_disposition_report TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict wEWyVcPhahDgzfaADojDZC7Q4cpr36cpb0Lbbzv3cZAxLer0dl4jt8MncncUzn7

