--
-- PostgreSQL database dump
--

\restrict iJFWfdbjbW0VkuS3Dt6bWadajaeQ79M4ImYhpIJTA2R7PdLTIfvHdblVGEcRkAv

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
-- Name: verified_products; Type: TABLE; Schema: culina; Owner: -
--

CREATE TABLE culina.verified_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    barcode character varying(50),
    verified_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: TABLE verified_products; Type: COMMENT; Schema: culina; Owner: -
--

COMMENT ON TABLE culina.verified_products IS 'Таблица верифицированных продуктов с UUID идентификаторами';


--
-- Name: COLUMN verified_products.meta; Type: COMMENT; Schema: culina; Owner: -
--

COMMENT ON COLUMN culina.verified_products.meta IS 'Метаданные продукта: БЖУ, калорийность, состав на русском языке и бренд';


--
-- Name: verified_products verified_products_barcode_key; Type: CONSTRAINT; Schema: culina; Owner: -
--

ALTER TABLE ONLY culina.verified_products
    ADD CONSTRAINT verified_products_barcode_key UNIQUE (barcode);


--
-- Name: verified_products verified_products_pkey; Type: CONSTRAINT; Schema: culina; Owner: -
--

ALTER TABLE ONLY culina.verified_products
    ADD CONSTRAINT verified_products_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict iJFWfdbjbW0VkuS3Dt6bWadajaeQ79M4ImYhpIJTA2R7PdLTIfvHdblVGEcRkAv

