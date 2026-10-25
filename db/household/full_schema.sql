--
-- PostgreSQL database dump
--

\restrict JvaXs4zWtgG4gkcnOxDWP1HTOXY0o3Ayf8OGlwBU4R4CjIP2N8ZpLqyxOBRmxbZ

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
-- Name: culina; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA culina;


--
-- Name: SCHEMA culina; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA culina IS 'Схема для кулинарного проекта и каталога продуктов';


--
-- Name: infrastructure; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA infrastructure;


--
-- Name: medicine; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA medicine;


--
-- Name: projects; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA projects;


--
-- Name: repair; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA repair;


--
-- Name: texere; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA texere;


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: schedule_status; Type: TYPE; Schema: medicine; Owner: -
--

CREATE TYPE medicine.schedule_status AS ENUM (
    'active',
    'completed',
    'overdue',
    'paused',
    'archived'
);


--
-- Name: mat_type; Type: TYPE; Schema: texere; Owner: -
--

CREATE TYPE texere.mat_type AS ENUM (
    'textile',
    'hardware',
    'consumable'
);


--
-- Name: fn_check_daily_supplement_limit(); Type: FUNCTION; Schema: medicine; Owner: -
--

CREATE FUNCTION medicine.fn_check_daily_supplement_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_already_taken INT4;
    v_supplement_name VARCHAR(255);
BEGIN
    -- Считаем, сколько единиц этого препарата УЖЕ было принято в указанный день
    -- (Исключаем текущую строку, если это UPDATE, чтобы не считать её дважды)
    SELECT COALESCE(SUM(amount), 0)
    INTO v_already_taken
    FROM medicine.intakes
    WHERE intake_date = NEW.intake_date
      AND supplement_id = NEW.supplement_id
      AND id <> NEW.id;

    -- Проверяем: если старое количество + новое превышает 5, выбрасываем ошибку
    IF (v_already_taken + NEW.amount) > 5 THEN
        -- Получаем название препарата для красивого текста ошибки
        SELECT name INTO v_supplement_name 
        FROM medicine.supplements 
        WHERE id = NEW.supplement_id;

        RAISE EXCEPTION 'Ошибка превышения суточной дозировки! Вы пытаетесь внести % шт. Препарат "%" на дату % уже принят в количестве % шт. Суммарный лимит превысит 5 шт. за день.', 
            NEW.amount, v_supplement_name, NEW.intake_date, v_already_taken;
    END IF;

    -- Если проверка прошла, разрешаем запись
    RETURN NEW;
END;
$$;


--
-- Name: fn_sync_schedule_statuses(); Type: FUNCTION; Schema: medicine; Owner: -
--

CREATE FUNCTION medicine.fn_sync_schedule_statuses() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Переводим в 'overdue' те курсы, которые активны, но их end_date уже в прошлом
    UPDATE medicine.schedules
    SET status = 'overdue'
    WHERE status = 'active' 
      AND end_date < CURRENT_DATE;
      
    -- (Опционально) Если курс был на паузе, но срок его конца наступил, 
    -- мы можем перевести его в completed или оставить в архиве на ваше усмотрение
END;
$$;


--
-- Name: update_receipts_from_transactions(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_receipts_from_transactions() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    updated_count integer;
BEGIN
    WITH transactions_agg AS (
        SELECT 
            amount, 
            operation_date, 
            array_agg(id::uuid) AS transaction_ids -- Принудительно делаем массив UUID
        FROM public.transactions
        WHERE contragent_to_id IS NOT NULL
        GROUP BY amount, operation_date
    )
    UPDATE processing.receipts r
    SET transaction_id = ta.transaction_ids
    FROM transactions_agg ta
    WHERE r.amount = ta.amount 
      AND r.operation_date = ta.operation_date 
      AND r.transaction_id IS NULL;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$;


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
-- Name: disposal_points; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.disposal_points (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255),
    type character varying(255),
    coordinates public.geography(Point,4326) NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    contragent_id uuid
);


--
-- Name: disposal_precedents; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.disposal_precedents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_disposition_id uuid NOT NULL,
    precedent_name character varying(255) NOT NULL,
    unit_type character varying(50) NOT NULL,
    quantity numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    notes text
);


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
-- Name: measuring_devices; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.measuring_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    device_name character varying(255) NOT NULL,
    max_weight numeric(15,3),
    unit character varying(50),
    uncertainty numeric(10,4),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: resource_catalog; Type: TABLE; Schema: infrastructure; Owner: -
--

CREATE TABLE infrastructure.resource_catalog (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_name character varying(255) NOT NULL,
    resource_type character varying(100),
    default_unit character varying(50),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    container_type character varying(100),
    notes text
);


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
-- Name: intakes; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.intakes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    intake_date date NOT NULL,
    supplement_id uuid NOT NULL,
    amount integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: observations; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.observations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    observation_date date NOT NULL,
    notes text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schedules; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.schedules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    supplement_id uuid NOT NULL,
    start_date date NOT NULL,
    end_date date,
    target_daily_amount integer NOT NULL,
    frequency_per_day integer DEFAULT 1 NOT NULL,
    notification_times time without time zone[] DEFAULT '{}'::time without time zone[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status medicine.schedule_status DEFAULT 'active'::medicine.schedule_status NOT NULL,
    CONSTRAINT check_dates CHECK (((end_date IS NULL) OR (end_date >= start_date))),
    CONSTRAINT check_positive_amount CHECK ((target_daily_amount > 0)),
    CONSTRAINT check_positive_frequency CHECK ((frequency_per_day > 0))
);


--
-- Name: supplements; Type: TABLE; Schema: medicine; Owner: -
--

CREATE TABLE medicine.supplements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    brand character varying(100),
    unit_type character varying(50) DEFAULT 'таблетка'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    description text,
    ingredients text,
    is_vegan boolean DEFAULT false NOT NULL,
    total_quantity integer,
    dosage_per_unit character varying(100),
    expiration_date_months integer
);


--
-- Name: COLUMN supplements.is_vegan; Type: COMMENT; Schema: medicine; Owner: -
--

COMMENT ON COLUMN medicine.supplements.is_vegan IS 'Флаг строго определен: true - подтвержденный веган, false - содержит животные компоненты / не проверен';


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
-- Name: metadata; Type: TABLE; Schema: projects; Owner: -
--

CREATE TABLE projects.metadata (
    project_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: projects; Type: TABLE; Schema: repair; Owner: -
--

CREATE TABLE repair.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    status character varying(50) DEFAULT 'planning'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: consumables_inventory; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.consumables_inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    consumable_type character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    merchant_name character varying(255),
    unit character varying(20) DEFAULT 'шт'::character varying NOT NULL,
    initial_quantity numeric(10,3) NOT NULL,
    current_balance numeric(10,3) NOT NULL,
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    price_per_unit numeric(12,2) GENERATED ALWAYS AS (
CASE
    WHEN (initial_quantity > (0)::numeric) THEN (total_cost_kzt / initial_quantity)
    ELSE 0.00
END) STORED,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_consumables_balance_limit CHECK ((current_balance <= initial_quantity)),
    CONSTRAINT consumables_inventory_current_balance_check CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT consumables_inventory_initial_quantity_check CHECK ((initial_quantity >= (0)::numeric)),
    CONSTRAINT consumables_inventory_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: external_services; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.external_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_type character varying(100) NOT NULL,
    description text NOT NULL,
    contractor_name character varying(255),
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT external_services_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: materials_inventory; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.materials_inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    material_type texere.mat_type NOT NULL,
    name character varying(255) NOT NULL,
    merchant_name character varying(255),
    unit character varying(20) DEFAULT 'м'::character varying NOT NULL,
    initial_quantity numeric(10,3) NOT NULL,
    current_balance numeric(10,3) NOT NULL,
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    price_per_unit numeric(12,2) GENERATED ALWAYS AS (
CASE
    WHEN (initial_quantity > (0)::numeric) THEN (total_cost_kzt / initial_quantity)
    ELSE 0.00
END) STORED,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_balance_limit CHECK ((current_balance <= initial_quantity)),
    CONSTRAINT materials_inventory_current_balance_check CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT materials_inventory_initial_quantity_check CHECK ((initial_quantity >= (0)::numeric)),
    CONSTRAINT materials_inventory_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: patterns_inventory; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.patterns_inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pattern_type character varying(50) DEFAULT 'Физическая'::character varying NOT NULL,
    product_category character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    size_range character varying(100),
    storage_location character varying(255),
    merchant_name character varying(255),
    unit character varying(20) DEFAULT 'компл'::character varying NOT NULL,
    initial_quantity numeric(10,3) DEFAULT 1.000 NOT NULL,
    current_balance numeric(10,3) DEFAULT 1.000 NOT NULL,
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    price_per_unit numeric(12,2) GENERATED ALWAYS AS (
CASE
    WHEN (initial_quantity > (0)::numeric) THEN (total_cost_kzt / initial_quantity)
    ELSE 0.00
END) STORED,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_patterns_balance_limit CHECK ((current_balance <= initial_quantity)),
    CONSTRAINT patterns_inventory_current_balance_check CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT patterns_inventory_initial_quantity_check CHECK ((initial_quantity >= (0)::numeric)),
    CONSTRAINT patterns_inventory_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: product_registry; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.product_registry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying(255) NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    materials jsonb DEFAULT '{}'::jsonb NOT NULL,
    meta jsonb DEFAULT '{}'::jsonb NOT NULL,
    completion_date date,
    quality_rating integer,
    comments text,
    original_photo character varying(2048),
    processed_photo character varying(2048),
    is_published boolean DEFAULT false NOT NULL,
    project_cost_kzt numeric(12,2),
    CONSTRAINT chk_quality_range CHECK (((quality_rating >= 1) AND (quality_rating <= 10)))
);


--
-- Name: raw_transactions; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.raw_transactions (
    tx_date date,
    tx_code integer,
    merchant character varying(255),
    status_desc character varying(100),
    status character varying(50),
    category character varying(100),
    description text,
    amount numeric(12,2),
    project character varying(255),
    uuid1 uuid,
    uuid2 uuid,
    uuid3 uuid,
    uuid4 uuid
);


--
-- Name: tools_inventory; Type: TABLE; Schema: texere; Owner: -
--

CREATE TABLE texere.tools_inventory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tool_type character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    merchant_name character varying(255),
    unit character varying(20) DEFAULT 'шт'::character varying NOT NULL,
    initial_quantity numeric(10,3) NOT NULL,
    scrapped_quantity numeric(10,3) DEFAULT 0.000 NOT NULL,
    total_cost_kzt numeric(12,2) DEFAULT 0.00 NOT NULL,
    price_per_unit numeric(12,2) GENERATED ALWAYS AS (
CASE
    WHEN (initial_quantity > (0)::numeric) THEN (total_cost_kzt / initial_quantity)
    ELSE 0.00
END) STORED,
    condition_status character varying(100) DEFAULT 'В работе'::character varying,
    transaction_uuid uuid,
    tx_code integer,
    entry_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_tools_scrapped_limit CHECK ((scrapped_quantity <= initial_quantity)),
    CONSTRAINT tools_inventory_initial_quantity_check CHECK ((initial_quantity >= (0)::numeric)),
    CONSTRAINT tools_inventory_scrapped_quantity_check CHECK ((scrapped_quantity >= (0)::numeric)),
    CONSTRAINT tools_inventory_total_cost_kzt_check CHECK ((total_cost_kzt >= (0)::numeric))
);


--
-- Name: reconciled_transactions_summary; Type: VIEW; Schema: texere; Owner: -
--

CREATE VIEW texere.reconciled_transactions_summary AS
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'materials_inventory'::text AS target_table,
    m.id AS record_id,
    m.name AS target_item_name,
    m.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.materials_inventory m ON (((m.transaction_uuid = t.uuid2) OR (m.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'consumables_inventory'::text AS target_table,
    c.id AS record_id,
    c.name AS target_item_name,
    c.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.consumables_inventory c ON (((c.transaction_uuid = t.uuid2) OR (c.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'patterns_inventory'::text AS target_table,
    p.id AS record_id,
    p.name AS target_item_name,
    p.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.patterns_inventory p ON (((p.transaction_uuid = t.uuid2) OR (p.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'tools_inventory'::text AS target_table,
    tool.id AS record_id,
    tool.name AS target_item_name,
    tool.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.tools_inventory tool ON (((tool.transaction_uuid = t.uuid2) OR (tool.tx_code = t.tx_code))))
UNION ALL
 SELECT t.tx_date,
    t.tx_code,
    t.merchant,
    t.amount AS original_amount,
    t.description AS original_description,
    t.uuid2 AS transaction_uuid,
    'external_services'::text AS target_table,
    s.id AS record_id,
    (((s.service_type)::text || ': '::text) || s.description) AS target_item_name,
    s.total_cost_kzt AS recorded_cost
   FROM (texere.raw_transactions t
     JOIN texere.external_services s ON (((s.transaction_uuid = t.uuid2) OR (s.tx_code = t.tx_code))));


--
-- Name: unreconciled_transactions; Type: VIEW; Schema: texere; Owner: -
--

CREATE VIEW texere.unreconciled_transactions AS
 SELECT tx_date,
    tx_code,
    merchant,
    amount,
    description,
    uuid2
   FROM texere.raw_transactions t
  WHERE (NOT (EXISTS ( SELECT 1
           FROM texere.materials_inventory m
          WHERE ((m.transaction_uuid = t.uuid2) OR (m.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.consumables_inventory c
          WHERE ((c.transaction_uuid = t.uuid2) OR (c.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.patterns_inventory p
          WHERE ((p.transaction_uuid = t.uuid2) OR (p.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.tools_inventory tool
          WHERE ((tool.transaction_uuid = t.uuid2) OR (tool.tx_code = t.tx_code))
        UNION ALL
         SELECT 1
           FROM texere.external_services s
          WHERE ((s.transaction_uuid = t.uuid2) OR (s.tx_code = t.tx_code)))));


--
-- Name: v_product_registry_analytics; Type: VIEW; Schema: texere; Owner: -
--

CREATE VIEW texere.v_product_registry_analytics AS
 SELECT id,
    title,
    completion_date,
    quantity,
        CASE
            WHEN (jsonb_typeof((meta -> 'tags'::text)) = 'array'::text) THEN ARRAY( SELECT jsonb_array_elements_text((p.meta -> 'tags'::text)) AS jsonb_array_elements_text)
            ELSE ARRAY[]::text[]
        END AS categories,
    quality_rating,
    project_cost_kzt,
    (NULLIF((meta ->> 'material_costs_kzt'::text), ''::text))::numeric AS material_costs_kzt,
    (NULLIF((meta ->> 'labor_costs_kzt'::text), ''::text))::numeric AS labor_costs_kzt,
    COALESCE(( SELECT sum((NULLIF((f.item ->> 'consumption_m'::text), ''::text))::numeric) AS sum
           FROM jsonb_array_elements(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'fabrics'::text)) = 'array'::text) THEN (p.materials -> 'fabrics'::text)
                    ELSE '[]'::jsonb
                END) f(item)), (0)::numeric) AS fabrics_consumption_m,
    COALESCE(( SELECT sum(COALESCE((NULLIF((i.item ->> 'total_consumption_m'::text), ''::text))::numeric, (NULLIF((i.item ->> 'consumption_m'::text), ''::text))::numeric, (0)::numeric)) AS sum
           FROM jsonb_each(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'items'::text)) = 'object'::text) THEN (p.materials -> 'items'::text)
                    ELSE '{}'::jsonb
                END) i(component_name, item)), (0)::numeric) AS items_consumption_m,
    (COALESCE(( SELECT sum((NULLIF((f.item ->> 'consumption_m'::text), ''::text))::numeric) AS sum
           FROM jsonb_array_elements(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'fabrics'::text)) = 'array'::text) THEN (p.materials -> 'fabrics'::text)
                    ELSE '[]'::jsonb
                END) f(item)), (0)::numeric) + COALESCE(( SELECT sum(COALESCE((NULLIF((i.item ->> 'total_consumption_m'::text), ''::text))::numeric, (NULLIF((i.item ->> 'consumption_m'::text), ''::text))::numeric, (0)::numeric)) AS sum
           FROM jsonb_each(
                CASE
                    WHEN (jsonb_typeof((p.materials -> 'items'::text)) = 'object'::text) THEN (p.materials -> 'items'::text)
                    ELSE '{}'::jsonb
                END) i(component_name, item)), (0)::numeric)) AS recorded_fabric_consumption_m,
    COALESCE(((meta ->> 'data_checked'::text))::boolean, false) AS data_checked,
    is_published,
    original_photo,
    processed_photo
   FROM texere.product_registry p;


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
-- Name: disposal_points disposal_points_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.disposal_points
    ADD CONSTRAINT disposal_points_pkey PRIMARY KEY (id);


--
-- Name: disposal_precedents disposal_precedents_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.disposal_precedents
    ADD CONSTRAINT disposal_precedents_pkey PRIMARY KEY (id);


--
-- Name: material_disposition material_disposition_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.material_disposition
    ADD CONSTRAINT material_disposition_pkey PRIMARY KEY (id);


--
-- Name: measuring_devices measuring_devices_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.measuring_devices
    ADD CONSTRAINT measuring_devices_pkey PRIMARY KEY (id);


--
-- Name: resource_catalog resource_catalog_pkey; Type: CONSTRAINT; Schema: infrastructure; Owner: -
--

ALTER TABLE ONLY infrastructure.resource_catalog
    ADD CONSTRAINT resource_catalog_pkey PRIMARY KEY (id);


--
-- Name: intakes intakes_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.intakes
    ADD CONSTRAINT intakes_pkey PRIMARY KEY (id);


--
-- Name: observations observations_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.observations
    ADD CONSTRAINT observations_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: supplements supplements_pkey; Type: CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.supplements
    ADD CONSTRAINT supplements_pkey PRIMARY KEY (id);


--
-- Name: metadata projects_metadata_pkey; Type: CONSTRAINT; Schema: projects; Owner: -
--

ALTER TABLE ONLY projects.metadata
    ADD CONSTRAINT projects_metadata_pkey PRIMARY KEY (project_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: repair; Owner: -
--

ALTER TABLE ONLY repair.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: consumables_inventory consumables_inventory_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.consumables_inventory
    ADD CONSTRAINT consumables_inventory_pkey PRIMARY KEY (id);


--
-- Name: external_services external_services_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.external_services
    ADD CONSTRAINT external_services_pkey PRIMARY KEY (id);


--
-- Name: materials_inventory materials_inventory_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.materials_inventory
    ADD CONSTRAINT materials_inventory_pkey PRIMARY KEY (id);


--
-- Name: patterns_inventory patterns_inventory_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.patterns_inventory
    ADD CONSTRAINT patterns_inventory_pkey PRIMARY KEY (id);


--
-- Name: product_registry product_registry_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.product_registry
    ADD CONSTRAINT product_registry_pkey PRIMARY KEY (id);


--
-- Name: tools_inventory tools_inventory_pkey; Type: CONSTRAINT; Schema: texere; Owner: -
--

ALTER TABLE ONLY texere.tools_inventory
    ADD CONSTRAINT tools_inventory_pkey PRIMARY KEY (id);


--
-- Name: idx_disposition_resource_date; Type: INDEX; Schema: infrastructure; Owner: -
--

CREATE INDEX idx_disposition_resource_date ON infrastructure.material_disposition USING btree (resource_id, utilized_at);


--
-- Name: idx_resource_name; Type: INDEX; Schema: infrastructure; Owner: -
--

CREATE INDEX idx_resource_name ON infrastructure.resource_catalog USING btree (material_name);


--
-- Name: idx_projects_metadata_meta; Type: INDEX; Schema: projects; Owner: -
--

CREATE INDEX idx_projects_metadata_meta ON projects.metadata USING gin (meta);


--
-- Name: idx_consumables_inv_active_balance; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_active_balance ON texere.consumables_inventory USING btree (current_balance) WHERE (current_balance > (0)::numeric);


--
-- Name: idx_consumables_inv_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_tx_code ON texere.consumables_inventory USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_consumables_inv_tx_link; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_tx_link ON texere.consumables_inventory USING btree (transaction_uuid) WHERE (transaction_uuid IS NOT NULL);


--
-- Name: idx_consumables_inv_type_name; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_consumables_inv_type_name ON texere.consumables_inventory USING btree (consumable_type, name);


--
-- Name: idx_external_services_lookup; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_external_services_lookup ON texere.external_services USING btree (service_type, contractor_name);


--
-- Name: idx_external_services_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_external_services_tx_code ON texere.external_services USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_materials_inv_active_balance; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_materials_inv_active_balance ON texere.materials_inventory USING btree (current_balance) WHERE (current_balance > (0)::numeric);


--
-- Name: idx_materials_inv_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_materials_inv_tx_code ON texere.materials_inventory USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_materials_inv_tx_link; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_materials_inv_tx_link ON texere.materials_inventory USING btree (transaction_uuid) WHERE (transaction_uuid IS NOT NULL);


--
-- Name: idx_materials_inv_type_name; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_materials_inv_type_name ON texere.materials_inventory USING btree (material_type, name);


--
-- Name: idx_patterns_inv_active_balance; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_patterns_inv_active_balance ON texere.patterns_inventory USING btree (current_balance) WHERE (current_balance > (0)::numeric);


--
-- Name: idx_patterns_inv_lookup; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_patterns_inv_lookup ON texere.patterns_inventory USING btree (product_category, pattern_type, name);


--
-- Name: idx_patterns_inv_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_patterns_inv_tx_code ON texere.patterns_inventory USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_patterns_inv_tx_link; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_patterns_inv_tx_link ON texere.patterns_inventory USING btree (transaction_uuid) WHERE (transaction_uuid IS NOT NULL);


--
-- Name: idx_product_registry_completion_date; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_completion_date ON texere.product_registry USING btree (completion_date);


--
-- Name: idx_product_registry_materials; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_materials ON texere.product_registry USING gin (materials);


--
-- Name: idx_product_registry_meta; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_meta ON texere.product_registry USING gin (meta);


--
-- Name: idx_product_registry_project_cost; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_product_registry_project_cost ON texere.product_registry USING btree (project_cost_kzt);


--
-- Name: idx_tools_inv_active; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_active ON texere.tools_inventory USING btree (initial_quantity) WHERE (initial_quantity > scrapped_quantity);


--
-- Name: idx_tools_inv_tx_code; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_tx_code ON texere.tools_inventory USING btree (tx_code) WHERE (tx_code IS NOT NULL);


--
-- Name: idx_tools_inv_tx_link; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_tx_link ON texere.tools_inventory USING btree (transaction_uuid) WHERE (transaction_uuid IS NOT NULL);


--
-- Name: idx_tools_inv_type_name; Type: INDEX; Schema: texere; Owner: -
--

CREATE INDEX idx_tools_inv_type_name ON texere.tools_inventory USING btree (tool_type, name);


--
-- Name: intakes trg_biu_check_daily_supplement_limit; Type: TRIGGER; Schema: medicine; Owner: -
--

CREATE TRIGGER trg_biu_check_daily_supplement_limit BEFORE INSERT OR UPDATE ON medicine.intakes FOR EACH ROW EXECUTE FUNCTION medicine.fn_check_daily_supplement_limit();


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
-- Name: intakes intakes_supplement_id_fkey; Type: FK CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.intakes
    ADD CONSTRAINT intakes_supplement_id_fkey FOREIGN KEY (supplement_id) REFERENCES medicine.supplements(id) ON DELETE CASCADE;


--
-- Name: schedules schedules_supplement_id_fkey; Type: FK CONSTRAINT; Schema: medicine; Owner: -
--

ALTER TABLE ONLY medicine.schedules
    ADD CONSTRAINT schedules_supplement_id_fkey FOREIGN KEY (supplement_id) REFERENCES medicine.supplements(id) ON DELETE CASCADE;


--
-- Name: SCHEMA infrastructure; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA infrastructure TO reflex_app_user;


--
-- Name: SCHEMA medicine; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA medicine TO reflex_app_user;


--
-- Name: SCHEMA projects; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA projects TO reflex_app_user;


--
-- Name: TABLE disposal_points; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.disposal_points TO reflex_app_user;


--
-- Name: TABLE disposal_precedents; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.disposal_precedents TO reflex_app_user;


--
-- Name: TABLE material_disposition; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.material_disposition TO reflex_app_user;


--
-- Name: TABLE measuring_devices; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.measuring_devices TO reflex_app_user;


--
-- Name: TABLE resource_catalog; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.resource_catalog TO reflex_app_user;


--
-- Name: TABLE v_material_disposition_report; Type: ACL; Schema: infrastructure; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE infrastructure.v_material_disposition_report TO reflex_app_user;


--
-- Name: TABLE intakes; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.intakes TO reflex_app_user;


--
-- Name: TABLE observations; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.observations TO reflex_app_user;


--
-- Name: TABLE schedules; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.schedules TO reflex_app_user;


--
-- Name: TABLE supplements; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.supplements TO reflex_app_user;


--
-- Name: TABLE v_intakes_analysis; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.v_intakes_analysis TO reflex_app_user;


--
-- Name: TABLE v_monthly_supplements_summary; Type: ACL; Schema: medicine; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE medicine.v_monthly_supplements_summary TO reflex_app_user;


--
-- Name: TABLE metadata; Type: ACL; Schema: projects; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE projects.metadata TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: infrastructure; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA infrastructure GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: medicine; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA medicine GRANT SELECT,USAGE ON SEQUENCES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: medicine; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA medicine GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: projects; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA projects GRANT SELECT,USAGE ON SEQUENCES TO reflex_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: projects; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA projects GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict JvaXs4zWtgG4gkcnOxDWP1HTOXY0o3Ayf8OGlwBU4R4CjIP2N8ZpLqyxOBRmxbZ

