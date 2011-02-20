CREATE TABLE activities (
    id integer primary key autoincrement,
    activity character varying(100),
    active boolean DEFAULT true
);

CREATE TABLE entries (
    id integer primary key autoincrement,
    invoice_id integer,
    project_id integer,
    activity_id integer,
    date date,
    "start" time with time zone,
    "end" time with time zone,
    description text,
    person character varying(30),
    order_number character varying(40),
    out_of_spec integer,
    module character varying(100),
    rate integer,
    charge boolean DEFAULT true
);


CREATE TABLE invoices (
    id integer primary key autoincrement,
    date date,
    client character varying(40),
    invoice_number character varying(8),
    status character varying(8),
    billing character varying(15),
    quote_date timestamp with time zone,
    quote_amount money,
    description character varying(100)
);


CREATE TABLE projects (
    id integer primary key autoincrement,
    project character varying(100),
    description text,
    order_number character varying(100),
    client character varying(100),
    rate integer,
    active boolean default true
);
