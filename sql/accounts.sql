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

--
SET default_tablespace = '';

SET default_with_oids = true;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: accounts; Tablespace: 
--

CREATE TABLE accounts (
    id integer DEFAULT nextval('accounts_id_seq'::text) NOT NULL,
    name character varying(80) NOT NULL,
    vat character varying(20) NOT NULL,
    account_type character varying(80),
    pastel_number character varying(8),
    fringe double precision,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.accounts OWNER TO accounts;

--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: accounts
--

CREATE SEQUENCE accounts_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.accounts_id_seq OWNER TO accounts;

--
-- Name: entries; Type: TABLE; Schema: public; Owner: accounts; Tablespace: 
--

CREATE TABLE entries (
    id integer DEFAULT nextval('entries_id'::text) NOT NULL,
    date date,
    description text,
    debit_id integer,
    credit_id integer,
    amount numeric(9,2),
    cheque_number character varying(10),
    active boolean DEFAULT true NOT NULL,
    vat boolean DEFAULT true NOT NULL
);


ALTER TABLE public.entries OWNER TO accounts;

--
-- Name: transactions; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW transactions AS
    SELECT entries.id, entries.date, entries.description, (SELECT accounts.name FROM accounts WHERE (accounts.id = entries.debit_id)) AS debit, (SELECT accounts.name FROM accounts WHERE (accounts.id = entries.credit_id)) AS credit, entries.amount, entries.cheque_number, entries.active, entries.vat FROM entries;


ALTER TABLE public.transactions OWNER TO accounts;

--
-- Name: values; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW "values" AS
    SELECT transactions.amount AS pre_vat_amount, transactions.id, transactions.date, transactions.description, transactions.debit, transactions.credit, transactions.cheque_number, transactions.vat, CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('year'::text, transactions.date) + (1)::double precision) ELSE date_part('year'::text, transactions.date) END AS financial_year, date_part('month'::text, transactions.date) AS "month" FROM transactions WHERE (transactions.active = true);


ALTER TABLE public."values" OWNER TO accounts;

--
-- Name: pre_amounts; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW pre_amounts AS
    ((SELECT "values".financial_year, to_char(("values".date)::timestamp with time zone, 'mon'::text) AS "month", "values".date, "values".description, "values".debit AS account, accounts.account_type, accounts.fringe, accounts.vat, (- "values".pre_vat_amount) AS pre_vat_amount, CASE WHEN (((accounts.vat)::text = 'yes'::text) AND ("values".vat = true)) THEN (((- float8("values".pre_vat_amount)) * (100.0)::double precision) / (114.0)::double precision) WHEN (((accounts.vat)::text = 'no'::text) OR ("values".vat = false)) THEN ((- "values".pre_vat_amount))::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN (0)::double precision ELSE NULL::double precision END AS amount FROM "values", accounts WHERE (("values".debit)::text = (accounts.name)::text) UNION SELECT "values".financial_year, to_char(("values".date)::timestamp with time zone, 'mon'::text) AS "month", "values".date, "values".description, 'VAT' AS account, 'Tax' AS account_type, accounts.fringe, accounts.vat, (- "values".pre_vat_amount) AS pre_vat_amount, CASE WHEN (((accounts.vat)::text = 'yes'::text) AND ("values".vat = true)) THEN (((- float8("values".pre_vat_amount)) * (14.0)::double precision) / (114.0)::double precision) WHEN (((accounts.vat)::text = 'no'::text) OR ("values".vat = false)) THEN (0)::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN ((- "values".pre_vat_amount))::double precision ELSE NULL::double precision END AS amount FROM "values", accounts WHERE (("values".debit)::text = (accounts.name)::text)) UNION SELECT "values".financial_year, to_char(("values".date)::timestamp with time zone, 'mon'::text) AS "month", "values".date, "values".description, "values".credit AS account, accounts.account_type, accounts.fringe, accounts.vat, "values".pre_vat_amount, CASE WHEN (((accounts.vat)::text = 'yes'::text) AND ("values".vat = true)) THEN ((float8("values".pre_vat_amount) * (100.0)::double precision) / (114.0)::double precision) WHEN (((accounts.vat)::text = 'no'::text) OR ("values".vat = false)) THEN ("values".pre_vat_amount)::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN (0)::double precision ELSE NULL::double precision END AS amount FROM "values", accounts WHERE (("values".credit)::text = (accounts.name)::text)) UNION SELECT "values".financial_year, to_char(("values".date)::timestamp with time zone, 'mon'::text) AS "month", "values".date, "values".description, 'VAT' AS account, 'Tax' AS account_type, accounts.fringe, accounts.vat, "values".pre_vat_amount, CASE WHEN (((accounts.vat)::text = 'yes'::text) AND ("values".vat = true)) THEN ((float8("values".pre_vat_amount) * (14.0)::double precision) / (114.0)::double precision) WHEN (((accounts.vat)::text = 'no'::text) OR ("values".vat = false)) THEN (0)::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN ("values".pre_vat_amount)::double precision ELSE NULL::double precision END AS amount FROM "values", accounts WHERE (("values".credit)::text = (accounts.name)::text);


ALTER TABLE public.pre_amounts OWNER TO accounts;

--
-- Name: amounts; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW amounts AS
    SELECT pre_amounts.financial_year, pre_amounts."month", pre_amounts.date, pre_amounts.description, pre_amounts.account, pre_amounts.account_type, pre_amounts.fringe, pre_amounts.vat, pre_amounts.pre_vat_amount, pre_amounts.amount, (pre_amounts.fringe * pre_amounts.amount) AS fringeamount FROM pre_amounts WHERE (NOT (pre_amounts.amount = (0)::double precision));


ALTER TABLE public.amounts OWNER TO accounts;

--
-- Name: bank_statement; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW bank_statement AS
    SELECT transactions.id, transactions.date, transactions.description, transactions.debit, transactions.credit, transactions.amount, transactions.cheque_number, transactions.active, transactions.vat, CASE WHEN ((transactions.debit)::text = 'Bank'::text) THEN (- transactions.amount) WHEN ((transactions.credit)::text = 'Bank'::text) THEN transactions.amount ELSE (0)::numeric END AS movement FROM transactions WHERE (((transactions.debit)::text = 'Bank'::text) OR ((transactions.credit)::text = 'Bank'::text)) ORDER BY transactions.date;


ALTER TABLE public.bank_statement OWNER TO accounts;

--
-- Name: running_total; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW running_total AS
    SELECT transactions.date, sum(CASE WHEN ((transactions.debit)::text = 'Bank'::text) THEN (- transactions.amount) WHEN ((transactions.credit)::text = 'Bank'::text) THEN transactions.amount ELSE (0)::numeric END) AS balance, CASE WHEN (date_part('month'::text, transactions.date) <= (2)::double precision) THEN (date_part('year'::text, transactions.date) - (1)::double precision) ELSE date_part('year'::text, transactions.date) END AS financial_year FROM transactions WHERE ((((transactions.debit)::text = 'Bank'::text) OR ((transactions.credit)::text = 'Bank'::text)) AND (transactions.active = true)) GROUP BY transactions.date;


ALTER TABLE public.running_total OWNER TO accounts;

--
-- Name: daily_2006; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW daily_2006 AS
    SELECT running_total.date, (SELECT sum(running.balance) AS sum FROM running_total running WHERE ((running.date >= '2006-03-01'::date) AND (running.date <= running_total.date))) AS balance FROM running_total WHERE ((running_total.date >= '2006-03-01'::date) AND (running_total.date < '2007-03-01'::date)) ORDER BY running_total.date;


ALTER TABLE public.daily_2006 OWNER TO accounts;

--
-- Name: daily_2007; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW daily_2007 AS
    SELECT running_total.date, (SELECT sum(running.balance) AS sum FROM running_total running WHERE ((running.date >= '2007-03-01'::date) AND (running.date <= running_total.date))) AS balance FROM running_total WHERE ((running_total.date >= '2007-03-01'::date) AND (running_total.date < '2008-03-01'::date)) ORDER BY running_total.date;


ALTER TABLE public.daily_2007 OWNER TO accounts;

--
-- Name: daily_2008; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW daily_2008 AS
    SELECT running_total.date, (SELECT sum(running.balance) AS sum FROM running_total running WHERE ((running.date >= '2008-03-01'::date) AND (running.date <= running_total.date))) AS balance FROM running_total WHERE ((running_total.date >= '2008-03-01'::date) AND (running_total.date < '2009-03-01'::date)) ORDER BY running_total.date;


ALTER TABLE public.daily_2008 OWNER TO accounts;

--
-- Name: daily_bank_balances; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW daily_bank_balances AS
    SELECT running_total.date, (SELECT sum(running.balance) AS sum FROM running_total running WHERE (running.date <= running_total.date)) AS balance FROM running_total ORDER BY running_total.date;


ALTER TABLE public.daily_bank_balances OWNER TO accounts;

--
-- Name: entries_id; Type: SEQUENCE; Schema: public; Owner: accounts
--

CREATE SEQUENCE entries_id
    INCREMENT BY 1
    MAXVALUE 2147483647
    NO MINVALUE
    CACHE 1;


ALTER TABLE public.entries_id OWNER TO accounts;

--
-- Name: pastel_export; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW pastel_export AS
    ((SELECT CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('year'::text, transactions.date) + (1)::double precision) ELSE date_part('year'::text, transactions.date) END AS financial_year, CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('month'::text, transactions.date) - (2)::double precision) ELSE (date_part('month'::text, transactions.date) + (10)::double precision) END AS period, transactions.date, 'G' AS gdc, accounts.pastel_number AS "Account Number", transactions.id AS reference, transactions.description, CASE WHEN ((accounts.vat)::text = 'yes'::text) THEN (((- float8(transactions.amount)) * (100.0)::double precision) / (114.0)::double precision) WHEN ((accounts.vat)::text = 'no'::text) THEN ((- transactions.amount))::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN (0)::double precision ELSE NULL::double precision END AS amount, 0 AS "Tax Type", 0 AS "Tax Amount", NULL::"unknown" AS "Open Item Type", NULL::"unknown" AS "Cost Code", NULL::"unknown" AS "Contra Account", 0.0 AS "Exchange Rate", 0.0 AS "Bank Exchange Rate", NULL::"unknown" AS "Batch ID", NULL::"unknown" AS "Discount Tax Type", NULL::"unknown" AS "Discount Amount", NULL::"unknown" AS "Home Amount", 'Debit Amount' AS debug FROM transactions, accounts WHERE ((((((accounts.name)::text = (transactions.debit)::text) AND ((accounts.account_type)::text <> 'Personal'::text)) AND (((SELECT accounts.account_type FROM accounts WHERE ((accounts.name)::text = (transactions.credit)::text)))::text <> 'Personal'::text)) AND (transactions.active = true)) AND (accounts.active = true)) UNION SELECT CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('year'::text, transactions.date) + (1)::double precision) ELSE date_part('year'::text, transactions.date) END AS financial_year, CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('month'::text, transactions.date) - (2)::double precision) ELSE (date_part('month'::text, transactions.date) + (10)::double precision) END AS period, transactions.date, 'G' AS gdc, '9500000' AS "Account Number", transactions.id AS reference, transactions.description, CASE WHEN ((accounts.vat)::text = 'yes'::text) THEN (((- float8(transactions.amount)) * (14.0)::double precision) / (114.0)::double precision) WHEN ((accounts.vat)::text = 'no'::text) THEN (0)::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN ((- transactions.amount))::double precision ELSE NULL::double precision END AS amount, 0 AS "Tax Type", 0 AS "Tax Amount", NULL::"unknown" AS "Open Item Type", NULL::"unknown" AS "Cost Code", NULL::"unknown" AS "Contra Account", 0.0 AS "Exchange Rate", 0.0 AS "Bank Exchange Rate", NULL::"unknown" AS "Batch ID", NULL::"unknown" AS "Discount Tax Type", NULL::"unknown" AS "Discount Amount", NULL::"unknown" AS "Home Amount", 'Debit VAT' AS debug FROM transactions, accounts WHERE ((((((accounts.name)::text = (transactions.debit)::text) AND ((accounts.account_type)::text <> 'Personal'::text)) AND (((SELECT accounts.account_type FROM accounts WHERE ((accounts.name)::text = (transactions.credit)::text)))::text <> 'Personal'::text)) AND (transactions.active = true)) AND (accounts.active = true))) UNION SELECT CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('year'::text, transactions.date) + (1)::double precision) ELSE date_part('year'::text, transactions.date) END AS financial_year, CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('month'::text, transactions.date) - (2)::double precision) ELSE (date_part('month'::text, transactions.date) + (10)::double precision) END AS period, transactions.date, 'G' AS gdc, accounts.pastel_number AS "Account Number", transactions.id AS reference, transactions.description, CASE WHEN ((accounts.vat)::text = 'yes'::text) THEN ((float8(transactions.amount) * (100.0)::double precision) / (114.0)::double precision) WHEN ((accounts.vat)::text = 'no'::text) THEN (transactions.amount)::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN (0)::double precision ELSE NULL::double precision END AS amount, 0 AS "Tax Type", 0 AS "Tax Amount", NULL::"unknown" AS "Open Item Type", NULL::"unknown" AS "Cost Code", NULL::"unknown" AS "Contra Account", 0.0 AS "Exchange Rate", 0.0 AS "Bank Exchange Rate", NULL::"unknown" AS "Batch ID", NULL::"unknown" AS "Discount Tax Type", NULL::"unknown" AS "Discount Amount", NULL::"unknown" AS "Home Amount", 'Credit Amount' AS debug FROM transactions, accounts WHERE ((((((accounts.name)::text = (transactions.credit)::text) AND ((accounts.account_type)::text <> 'Personal'::text)) AND (((SELECT accounts.account_type FROM accounts WHERE ((accounts.name)::text = (transactions.debit)::text)))::text <> 'Personal'::text)) AND (transactions.active = true)) AND (accounts.active = true))) UNION SELECT CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('year'::text, transactions.date) + (1)::double precision) ELSE date_part('year'::text, transactions.date) END AS financial_year, CASE WHEN (date_part('month'::text, transactions.date) > (2)::double precision) THEN (date_part('month'::text, transactions.date) - (2)::double precision) ELSE (date_part('month'::text, transactions.date) + (10)::double precision) END AS period, transactions.date, 'G' AS gdc, '9500000' AS "Account Number", transactions.id AS reference, transactions.description, CASE WHEN ((accounts.vat)::text = 'yes'::text) THEN ((float8(transactions.amount) * (14.0)::double precision) / (114.0)::double precision) WHEN ((accounts.vat)::text = 'no'::text) THEN (0)::double precision WHEN ((accounts.vat)::text = 'all'::text) THEN (transactions.amount)::double precision ELSE NULL::double precision END AS amount, 0 AS "Tax Type", 0 AS "Tax Amount", NULL::"unknown" AS "Open Item Type", NULL::"unknown" AS "Cost Code", NULL::"unknown" AS "Contra Account", 0.0 AS "Exchange Rate", 0.0 AS "Bank Exchange Rate", NULL::"unknown" AS "Batch ID", NULL::"unknown" AS "Discount Tax Type", NULL::"unknown" AS "Discount Amount", NULL::"unknown" AS "Home Amount", 'Credit VAT' AS debug FROM transactions, accounts WHERE ((((((accounts.name)::text = (transactions.credit)::text) AND ((accounts.account_type)::text <> 'Personal'::text)) AND (((SELECT accounts.account_type FROM accounts WHERE ((accounts.name)::text = (transactions.debit)::text)))::text <> 'Personal'::text)) AND (transactions.active = true)) AND (accounts.active = true));


ALTER TABLE public.pastel_export OWNER TO accounts;

--
-- Name: pastel_2008; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW pastel_2008 AS
    SELECT pastel_export.period, pastel_export.date, pastel_export.gdc, pastel_export."Account Number", pastel_export.reference, pastel_export.description, pastel_export.amount, pastel_export."Tax Type", pastel_export."Tax Amount", pastel_export."Open Item Type", pastel_export."Cost Code", pastel_export."Contra Account", pastel_export."Exchange Rate", pastel_export."Bank Exchange Rate", pastel_export."Batch ID", pastel_export."Discount Tax Type", pastel_export."Discount Amount", pastel_export."Home Amount" FROM pastel_export WHERE ((pastel_export.financial_year = (2008)::double precision) AND (NOT (pastel_export.amount = float8(0.0))));


ALTER TABLE public.pastel_2008 OWNER TO accounts;

--
-- Name: pastel_accounts; Type: TABLE; Schema: public; Owner: accounts; Tablespace: 
--

CREATE TABLE pastel_accounts (
    account_number character varying(7),
    description character varying(40),
    financial_category character varying(3),
    external_reference character varying(12),
    tax_type character(1),
    tax_method character(2)
);


ALTER TABLE public.pastel_accounts OWNER TO accounts;

--
-- Name: transaction_description; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW transaction_description AS
    SELECT DISTINCT entries.description FROM entries ORDER BY entries.description;


ALTER TABLE public.transaction_description OWNER TO accounts;

--
-- Name: vat_summary; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW vat_summary AS
    SELECT pre_amounts.financial_year, pre_amounts."month", pre_amounts.date, pre_amounts.description, pre_amounts.account, pre_amounts.account_type, pre_amounts.fringe, pre_amounts.vat, pre_amounts.pre_vat_amount, pre_amounts.amount, date_part('year'::text, pre_amounts.date) AS "year", CASE WHEN ((pre_amounts.vat)::text = 'yes'::text) THEN (float8(pre_amounts.pre_vat_amount) - pre_amounts.amount) WHEN ((pre_amounts.vat)::text = 'all'::text) THEN (pre_amounts.pre_vat_amount)::double precision ELSE (0)::double precision END AS vat_amount, CASE WHEN ((date_part('month'::text, pre_amounts.date) = (1)::double precision) OR (date_part('month'::text, pre_amounts.date) = (2)::double precision)) THEN '8 Jan - Feb'::text WHEN ((date_part('month'::text, pre_amounts.date) = (3)::double precision) OR (date_part('month'::text, pre_amounts.date) = (4)::double precision)) THEN '1 Mar - Apr'::text WHEN ((date_part('month'::text, pre_amounts.date) = (5)::double precision) OR (date_part('month'::text, pre_amounts.date) = (6)::double precision)) THEN '3 May - Jun'::text WHEN ((date_part('month'::text, pre_amounts.date) = (7)::double precision) OR (date_part('month'::text, pre_amounts.date) = (8)::double precision)) THEN '4 Jul - Aug'::text WHEN ((date_part('month'::text, pre_amounts.date) = (9)::double precision) OR (date_part('month'::text, pre_amounts.date) = (10)::double precision)) THEN '5 Sep - Oct'::text WHEN ((date_part('month'::text, pre_amounts.date) = (11)::double precision) OR (date_part('month'::text, pre_amounts.date) = (12)::double precision)) THEN '6 Nov - Dec'::text ELSE NULL::text END AS vat_period FROM pre_amounts WHERE (NOT ((pre_amounts.vat)::text = 'no'::text));


ALTER TABLE public.vat_summary OWNER TO accounts;

--
-- Name: vat_totals; Type: VIEW; Schema: public; Owner: accounts
--

CREATE VIEW vat_totals AS
    SELECT vat_summary.financial_year, vat_summary.vat_period, vat_summary.account_type, sum(vat_summary.pre_vat_amount) AS pre_vat_amount, sum(vat_summary.vat_amount) AS vat_amount FROM vat_summary WHERE (((((vat_summary.account_type)::text = 'Assets'::text) OR ((vat_summary.account_type)::text = 'Expenses'::text)) OR ((vat_summary.account_type)::text = 'Income'::text)) OR ((vat_summary.account_type)::text = 'VAT'::text)) GROUP BY vat_summary.financial_year, vat_summary.vat_period, vat_summary.account_type ORDER BY vat_summary.financial_year, vat_summary.vat_period, vat_summary.account_type;


ALTER TABLE public.vat_totals OWNER TO accounts;

--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: accounts; Tablespace: 
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (name);


ALTER INDEX public.accounts_pkey OWNER TO accounts;

--
-- Name: entries_pkey; Type: CONSTRAINT; Schema: public; Owner: accounts; Tablespace: 
--

ALTER TABLE ONLY entries
    ADD CONSTRAINT entries_pkey PRIMARY KEY (id);


ALTER INDEX public.entries_pkey OWNER TO accounts;

--
-- Name: entries_date; Type: INDEX; Schema: public; Owner: accounts; Tablespace: 
--

CREATE INDEX entries_date ON entries USING btree (date);


ALTER INDEX public.entries_date OWNER TO accounts;

--
-- Name: entries_description; Type: INDEX; Schema: public; Owner: accounts; Tablespace: 
--

CREATE INDEX entries_description ON entries USING btree (description);


ALTER INDEX public.entries_description OWNER TO accounts;

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

