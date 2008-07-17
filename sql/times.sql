--
-- PostgreSQL database dump
--

SET client_encoding = 'LATIN1';
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = true;

--
-- Name: activities; Type: TABLE; Schema: public; Owner: panic; Tablespace: 
--

CREATE TABLE activities (
    id bigint NOT NULL,
    activity character varying(100),
    active boolean DEFAULT true
);


ALTER TABLE public.activities OWNER TO panic;

--
-- Name: entries; Type: TABLE; Schema: public; Owner: panic; Tablespace: 
--

CREATE TABLE entries (
    id integer DEFAULT nextval('entries_id_seq'::text) NOT NULL,
    invoice_id integer,
    project_id integer,
    activity_id integer,
    date date,
    "start" time without time zone,
    "end" time without time zone,
    description text,
    person character varying(30),
    order_number character varying(40),
    out_of_spec integer,
    module character varying(100),
    rate integer,
    charge boolean DEFAULT true
);


ALTER TABLE public.entries OWNER TO panic;

--
-- Name: entries_id_seq; Type: SEQUENCE; Schema: public; Owner: panic
--

CREATE SEQUENCE entries_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.entries_id_seq OWNER TO panic;

--
-- Name: invoices; Type: TABLE; Schema: public; Owner: panic; Tablespace: 
--

CREATE TABLE invoices (
    id integer DEFAULT nextval('invoices_id_seq'::text) NOT NULL,
    date date,
    client character varying(40),
    invoice_number character varying(8),
    status character varying(8),
    billing character varying(15),
    quote_date timestamp without time zone,
    quote_amount money,
    description character varying(100)
);


ALTER TABLE public.invoices OWNER TO panic;

--
-- Name: invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: panic
--

CREATE SEQUENCE invoices_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.invoices_id_seq OWNER TO panic;

--
-- Name: projects; Type: TABLE; Schema: public; Owner: panic; Tablespace: 
--

CREATE TABLE projects (
    id integer DEFAULT nextval('projects_id_seq'::text) NOT NULL,
    project character varying(100),
    description text,
    order_number character varying(100),
    client character varying(100),
    rate integer,
    active boolean
);


ALTER TABLE public.projects OWNER TO panic;

--
-- Name: nice_entries; Type: VIEW; Schema: public; Owner: panic
--

CREATE VIEW nice_entries AS
    SELECT entries.id, invoices.invoice_number, invoices.status, projects.project, activities.activity, ((entries."end" - entries."start"))::time without time zone AS elapsed, entries.date, entries."start", entries."end", entries.description, entries.person, entries.order_number, entries.out_of_spec, entries.module, entries.rate, entries.charge FROM (((entries JOIN activities ON ((entries.activity_id = activities.id))) JOIN projects ON ((entries.project_id = projects.id))) JOIN invoices ON ((entries.invoice_id = invoices.id)));


ALTER TABLE public.nice_entries OWNER TO panic;

--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: panic
--

CREATE SEQUENCE projects_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.projects_id_seq OWNER TO panic;

--
-- Name: activities_pkey; Type: CONSTRAINT; Schema: public; Owner: panic; Tablespace: 
--

ALTER TABLE ONLY activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


ALTER INDEX public.activities_pkey OWNER TO panic;

--
-- Name: entries_pkey; Type: CONSTRAINT; Schema: public; Owner: panic; Tablespace: 
--

ALTER TABLE ONLY entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


ALTER INDEX public.entries_pkey OWNER TO panic;

--
-- Name: invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: panic; Tablespace: 
--

ALTER TABLE ONLY invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


ALTER INDEX public.invoices_pkey OWNER TO panic;

--
-- Name: projects_pkey; Type: CONSTRAINT; Schema: public; Owner: panic; Tablespace: 
--

ALTER TABLE ONLY projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


ALTER INDEX public.projects_pkey OWNER TO panic;

--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

