--
-- PostgreSQL database dump
--

\restrict afd1ndRY1dZpgnsXDVPvh9eHMnoqKtDY9uaVGbBpeTOnTlGdKbbj7ns8ZQODoPm

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
-- Name: transactions; Type: VIEW; Schema: reports; Owner: -
--

CREATE VIEW reports.transactions AS
 SELECT t.code,
    t.registration_date,
    t.operation_date,
    t.operation_time,
    t.created_at,
    e.entity_name,
    cat.category_name,
    c_from.contragent_name AS contragent_from_name,
    addr_from.address_name AS contragent_from_address,
    c_to.contragent_name AS contragent_to_name,
    addr_to.address_name AS contragent_to_address,
    acc.account_name,
    dt.type_name,
    t.amount
   FROM ((((((((public.transactions t
     LEFT JOIN dicts.entities e ON ((t.entity_id = e.id)))
     LEFT JOIN dicts.contragents c_from ON ((t.contragent_from_id = c_from.id)))
     LEFT JOIN dicts.addresses addr_from ON ((c_from.address_id = addr_from.id)))
     LEFT JOIN dicts.contragents c_to ON ((t.contragent_to_id = c_to.id)))
     LEFT JOIN dicts.addresses addr_to ON ((c_to.address_id = addr_to.id)))
     LEFT JOIN dicts.dict_categories cat ON ((t.category_id = cat.id)))
     LEFT JOIN dicts.accounts acc ON ((t.account_id = acc.id)))
     LEFT JOIN dicts.dict_types dt ON ((t.type_id = dt.id)))
  ORDER BY t.code DESC;


--
-- Name: TABLE transactions; Type: ACL; Schema: reports; Owner: -
--

GRANT SELECT ON TABLE reports.transactions TO reflex_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict afd1ndRY1dZpgnsXDVPvh9eHMnoqKtDY9uaVGbBpeTOnTlGdKbbj7ns8ZQODoPm

