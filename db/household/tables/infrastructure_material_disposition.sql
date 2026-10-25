--
-- PostgreSQL database dump
--

\restrict deLpojnX1qWSliN3yM9PYb48ww0JaqjRggcnEu8vSRPgEWlKh8Z8dedij3e6HHA

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
-- Name: material_disposition; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.material_disposition (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_id uuid NOT NULL,
    quantity numeric(15,3) NOT NULL,
    utilized_at date DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    device_id uuid,
    weighing_type character varying(50) DEFAULT 'gross'::character varying NOT NULL,
    disposal_point uuid NOT NULL
);


--
-- Name: material_disposition material_disposition_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.material_disposition
    ADD CONSTRAINT material_disposition_pkey PRIMARY KEY (id);


--
-- Name: idx_disposition_resource_date; Type: INDEX; Schema: infrastructure; Owner: -
--

CREATE INDEX idx_disposition_resource_date ON infrastructure.material_disposition USING btree (resource_id, utilized_at);


--
-- Name: material_disposition fk_device_id; Type: FK CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.material_disposition
    ADD CONSTRAINT fk_device_id FOREIGN KEY (device_id) REFERENCES infrastructure.measuring_devices(id);


--
-- Name: material_disposition fk_resource_id; Type: FK CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.material_disposition
    ADD CONSTRAINT fk_resource_id FOREIGN KEY (resource_id) REFERENCES infrastructure.resource_catalog(id);


--
-- Name: TABLE material_disposition; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.material_disposition TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict deLpojnX1qWSliN3yM9PYb48ww0JaqjRggcnEu8vSRPgEWlKh8Z8dedij3e6HHA

