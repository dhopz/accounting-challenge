--
-- PostgreSQL database dump
--

-- Dumped from database version 14.0
-- Dumped by pg_dump version 14.2

-- Started on 2022-03-29 16:46:07 BST

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 243 (class 1255 OID 19532)
-- Name: fee_conversion(); Type: FUNCTION; Schema: public; Owner: davidhoupapa
--

CREATE FUNCTION public.fee_conversion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fx_ledger(fx_tran_id,currency,realised_fx,rate) 
SELECT 
t1.id,
t1.currency_from,
CASE t1.currency_from WHEN 'GBP' THEN t3.fee ELSE ROUND(t3.fee * t2.sell,2) END AS fx_realised,
CASE t1.currency_from WHEN 'GBP' THEN 1 ELSE t2.sell END AS sell_rate
FROM
    (SELECT *,CONCAT('GBP',currency_from) AS currency_pair FROM fx_transaction ORDER BY date DESC LIMIT 1) t1
LEFT JOIN 
    (SELECT id,buy,sell,currency_pair FROM fx_table ORDER BY date DESC) t2 
ON (t2.currency_pair = t1.currency_pair)
LEFT JOIN
    currencies t3
ON (t1.currency_from = t3.currency)
ORDER BY date DESC LIMIT 1;
RETURN new;
END;
$$;


ALTER FUNCTION public.fee_conversion() OWNER TO davidhoupapa;

--
-- TOC entry 234 (class 1255 OID 19459)
-- Name: fx_conversion(); Type: FUNCTION; Schema: public; Owner: davidhoupapa
--

CREATE FUNCTION public.fx_conversion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO fx_transaction(transaction_id,customer_id,transaction_amount,fee,amount_to_convert,converted,rate,currency_from,currency_to,currency_rate_id) 
SELECT 
t1.id,t1.customer_id,t1.amount,t3.fee,t1.amount - t3.fee AS amount_to_convert,(t1.amount - t3.fee) * t2.buy AS converted,t2.buy AS buy_rate,t1.currency_from,t1.currency_to, t2.id
FROM
    (SELECT *,CONCAT(currency_from,currency_to) AS currency_pair FROM customer_transaction ORDER BY date DESC LIMIT 1) t1
LEFT JOIN 
    (SELECT id,buy,sell,currency_pair FROM fx_table ORDER BY date DESC) t2 
ON (t2.currency_pair = t1.currency_pair)
LEFT JOIN
    currencies t3
ON (t1.currency_from = t3.currency)
ORDER BY date DESC LIMIT 1;
RETURN new;
END;
$$;


ALTER FUNCTION public.fx_conversion() OWNER TO davidhoupapa;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 219 (class 1259 OID 19445)
-- Name: fx_transaction; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.fx_transaction (
    id integer NOT NULL,
    customer_id integer,
    transaction_id integer NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    fee numeric NOT NULL,
    transaction_amount numeric NOT NULL,
    amount_to_convert numeric NOT NULL,
    converted numeric NOT NULL,
    rate numeric NOT NULL,
    currency_from character varying(3) NOT NULL,
    currency_to character varying(3) NOT NULL,
    deferred boolean DEFAULT false,
    pair character varying(6) GENERATED ALWAYS AS (((currency_from)::text || (currency_to)::text)) STORED,
    currency_rate_id integer NOT NULL
);


ALTER TABLE public.fx_transaction OWNER TO davidhoupapa;

--
-- TOC entry 222 (class 1259 OID 19475)
-- Name: e1_accounts; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.e1_accounts AS
 SELECT fx_transaction.currency_from AS currency,
    sum(fx_transaction.transaction_amount) AS cash,
    sum((- fx_transaction.amount_to_convert)) AS customer_liability,
    sum(
        CASE fx_transaction.deferred
            WHEN false THEN (- fx_transaction.fee)
            ELSE NULL::numeric
        END) AS revenue,
    sum(
        CASE fx_transaction.deferred
            WHEN true THEN (- fx_transaction.fee)
            ELSE NULL::numeric
        END) AS intercompany_payable
   FROM public.fx_transaction
  GROUP BY fx_transaction.currency_from;


ALTER TABLE public.e1_accounts OWNER TO davidhoupapa;

--
-- TOC entry 226 (class 1259 OID 19485)
-- Name: fx_ledger; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.fx_ledger (
    id integer NOT NULL,
    fx_tran_id integer NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    currency character varying(3),
    realised_fx numeric,
    rate numeric
);


ALTER TABLE public.fx_ledger OWNER TO davidhoupapa;

--
-- TOC entry 228 (class 1259 OID 19534)
-- Name: fx_realised; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.fx_realised AS
 SELECT sum(fx_ledger.realised_fx) AS realized_fx,
    'GBP'::text AS reporting_currency
   FROM public.fx_ledger
  WHERE ((fx_ledger.currency)::text <> 'GBP'::text);


ALTER TABLE public.fx_realised OWNER TO davidhoupapa;

--
-- TOC entry 229 (class 1259 OID 19538)
-- Name: fx_accounts; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.fx_accounts AS
 SELECT e1_accounts.cash,
    e1_accounts.customer_liability,
    e1_accounts.revenue,
    e1_accounts.intercompany_payable,
    fx_realised.realized_fx
   FROM (public.e1_accounts
     JOIN public.fx_realised ON ((fx_realised.reporting_currency = (e1_accounts.currency)::text)));


ALTER TABLE public.fx_accounts OWNER TO davidhoupapa;

--
-- TOC entry 230 (class 1259 OID 19542)
-- Name: accounts; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.accounts AS
 SELECT unnest(ARRAY['cash'::text, 'customer_liability'::text, 'revenue'::text, 'intercompany_payable'::text, 'realized_fx'::text]) AS "Ledger",
    unnest(ARRAY[fx_accounts.cash, fx_accounts.customer_liability, fx_accounts.revenue, fx_accounts.intercompany_payable, fx_accounts.realized_fx]) AS "GBP"
   FROM public.fx_accounts;


ALTER TABLE public.accounts OWNER TO davidhoupapa;

--
-- TOC entry 210 (class 1259 OID 19248)
-- Name: currencies; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.currencies (
    id integer NOT NULL,
    currency character varying(5),
    name character varying(20),
    fee numeric
);


ALTER TABLE public.currencies OWNER TO davidhoupapa;

--
-- TOC entry 209 (class 1259 OID 19247)
-- Name: currencies_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.currencies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currencies_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3691 (class 0 OID 0)
-- Dependencies: 209
-- Name: currencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.currencies_id_seq OWNED BY public.currencies.id;


--
-- TOC entry 212 (class 1259 OID 19362)
-- Name: currency_rate; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.currency_rate (
    id integer NOT NULL,
    currency_id integer NOT NULL,
    pair character varying(3),
    buy numeric,
    sell numeric GENERATED ALWAYS AS (((1)::numeric / buy)) STORED NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.currency_rate OWNER TO davidhoupapa;

--
-- TOC entry 211 (class 1259 OID 19361)
-- Name: currency_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.currency_rate_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_rate_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3692 (class 0 OID 0)
-- Dependencies: 211
-- Name: currency_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.currency_rate_id_seq OWNED BY public.currency_rate.id;


--
-- TOC entry 216 (class 1259 OID 19404)
-- Name: customer_transaction; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.customer_transaction (
    id integer NOT NULL,
    customer_id integer,
    date timestamp without time zone DEFAULT now() NOT NULL,
    amount numeric NOT NULL,
    currency_from character varying(3) NOT NULL,
    currency_to character varying(3) NOT NULL,
    pair character varying(6) GENERATED ALWAYS AS (((currency_from)::text || (currency_to)::text)) STORED
);


ALTER TABLE public.customer_transaction OWNER TO davidhoupapa;

--
-- TOC entry 220 (class 1259 OID 19455)
-- Name: fx_table; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.fx_table AS
 SELECT currencies.currency,
    currency_rate.pair,
    currency_rate.buy,
    currency_rate.sell,
    currency_rate.date,
    concat(currencies.currency, currency_rate.pair) AS currency_pair,
    currency_rate.id
   FROM (public.currency_rate
     JOIN public.currencies ON ((currencies.id = currency_rate.currency_id)));


ALTER TABLE public.fx_table OWNER TO davidhoupapa;

--
-- TOC entry 221 (class 1259 OID 19465)
-- Name: cust_tran; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.cust_tran AS
 SELECT t1.customer_id,
    t1.amount,
    t3.fee,
    (t1.amount - t3.fee) AS amount_to_convert,
    ((t1.amount - t3.fee) * t2.buy) AS converted,
    t2.buy AS buy_rate,
    t1.currency_from,
    t1.currency_to
   FROM ((( SELECT customer_transaction.id,
            customer_transaction.customer_id,
            customer_transaction.date,
            customer_transaction.amount,
            customer_transaction.currency_from,
            customer_transaction.currency_to,
            concat(customer_transaction.currency_from, customer_transaction.currency_to) AS currency_pair
           FROM public.customer_transaction
          ORDER BY customer_transaction.date DESC
         LIMIT 1) t1
     LEFT JOIN ( SELECT fx_table.buy,
            fx_table.sell,
            fx_table.currency_pair
           FROM public.fx_table
          ORDER BY fx_table.date DESC) t2 ON ((t2.currency_pair = t1.currency_pair)))
     LEFT JOIN public.currencies t3 ON (((t1.currency_from)::text = (t3.currency)::text)))
  ORDER BY t1.date DESC
 LIMIT 1;


ALTER TABLE public.cust_tran OWNER TO davidhoupapa;

--
-- TOC entry 214 (class 1259 OID 19378)
-- Name: customer; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.customer (
    id integer NOT NULL,
    name character varying(20)
);


ALTER TABLE public.customer OWNER TO davidhoupapa;

--
-- TOC entry 213 (class 1259 OID 19377)
-- Name: customer_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.customer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.customer_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3693 (class 0 OID 0)
-- Dependencies: 213
-- Name: customer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.customer_id_seq OWNED BY public.customer.id;


--
-- TOC entry 215 (class 1259 OID 19403)
-- Name: customer_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.customer_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.customer_transaction_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3694 (class 0 OID 0)
-- Dependencies: 215
-- Name: customer_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.customer_transaction_id_seq OWNED BY public.customer_transaction.id;


--
-- TOC entry 223 (class 1259 OID 19479)
-- Name: e2_accounts; Type: VIEW; Schema: public; Owner: davidhoupapa
--

CREATE VIEW public.e2_accounts AS
 SELECT e1_accounts.currency,
    e1_accounts.cash,
    e1_accounts.customer_liability,
    e1_accounts.revenue,
    e1_accounts.intercompany_payable,
    (- e1_accounts.intercompany_payable) AS intercompany_receivable
   FROM public.e1_accounts;


ALTER TABLE public.e2_accounts OWNER TO davidhoupapa;

--
-- TOC entry 225 (class 1259 OID 19484)
-- Name: fx_ledger_fx_tran_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.fx_ledger_fx_tran_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fx_ledger_fx_tran_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3695 (class 0 OID 0)
-- Dependencies: 225
-- Name: fx_ledger_fx_tran_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.fx_ledger_fx_tran_id_seq OWNED BY public.fx_ledger.fx_tran_id;


--
-- TOC entry 224 (class 1259 OID 19483)
-- Name: fx_ledger_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.fx_ledger_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fx_ledger_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3696 (class 0 OID 0)
-- Dependencies: 224
-- Name: fx_ledger_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.fx_ledger_id_seq OWNED BY public.fx_ledger.id;


--
-- TOC entry 227 (class 1259 OID 19519)
-- Name: fx_transaction_currency_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.fx_transaction_currency_rate_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fx_transaction_currency_rate_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3697 (class 0 OID 0)
-- Dependencies: 227
-- Name: fx_transaction_currency_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.fx_transaction_currency_rate_id_seq OWNED BY public.fx_transaction.currency_rate_id;


--
-- TOC entry 217 (class 1259 OID 19443)
-- Name: fx_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.fx_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fx_transaction_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3698 (class 0 OID 0)
-- Dependencies: 217
-- Name: fx_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.fx_transaction_id_seq OWNED BY public.fx_transaction.id;


--
-- TOC entry 218 (class 1259 OID 19444)
-- Name: fx_transaction_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: davidhoupapa
--

CREATE SEQUENCE public.fx_transaction_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fx_transaction_transaction_id_seq OWNER TO davidhoupapa;

--
-- TOC entry 3699 (class 0 OID 0)
-- Dependencies: 218
-- Name: fx_transaction_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.fx_transaction_transaction_id_seq OWNED BY public.fx_transaction.transaction_id;


--
-- TOC entry 3489 (class 2604 OID 19251)
-- Name: currencies id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currencies ALTER COLUMN id SET DEFAULT nextval('public.currencies_id_seq'::regclass);


--
-- TOC entry 3490 (class 2604 OID 19365)
-- Name: currency_rate id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currency_rate ALTER COLUMN id SET DEFAULT nextval('public.currency_rate_id_seq'::regclass);


--
-- TOC entry 3493 (class 2604 OID 19381)
-- Name: customer id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer ALTER COLUMN id SET DEFAULT nextval('public.customer_id_seq'::regclass);


--
-- TOC entry 3494 (class 2604 OID 19407)
-- Name: customer_transaction id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer_transaction ALTER COLUMN id SET DEFAULT nextval('public.customer_transaction_id_seq'::regclass);


--
-- TOC entry 3503 (class 2604 OID 19488)
-- Name: fx_ledger id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger ALTER COLUMN id SET DEFAULT nextval('public.fx_ledger_id_seq'::regclass);


--
-- TOC entry 3504 (class 2604 OID 19489)
-- Name: fx_ledger fx_tran_id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger ALTER COLUMN fx_tran_id SET DEFAULT nextval('public.fx_ledger_fx_tran_id_seq'::regclass);


--
-- TOC entry 3497 (class 2604 OID 19448)
-- Name: fx_transaction id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction ALTER COLUMN id SET DEFAULT nextval('public.fx_transaction_id_seq'::regclass);


--
-- TOC entry 3498 (class 2604 OID 19449)
-- Name: fx_transaction transaction_id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction ALTER COLUMN transaction_id SET DEFAULT nextval('public.fx_transaction_transaction_id_seq'::regclass);


--
-- TOC entry 3502 (class 2604 OID 19520)
-- Name: fx_transaction currency_rate_id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction ALTER COLUMN currency_rate_id SET DEFAULT nextval('public.fx_transaction_currency_rate_id_seq'::regclass);


--
-- TOC entry 3672 (class 0 OID 19248)
-- Dependencies: 210
-- Data for Name: currencies; Type: TABLE DATA; Schema: public; Owner: davidhoupapa
--

COPY public.currencies (id, currency, name, fee) FROM stdin;
3	EUR	Euro	5
4	AUD	Australian Dollar	5
5	CZK	Czech Koruna	10
6	HKD	Hong Kong Dollars	5
2	USD	US Dollar	5
1	GBP	British Pound	5
\.


--
-- TOC entry 3674 (class 0 OID 19362)
-- Dependencies: 212
-- Data for Name: currency_rate; Type: TABLE DATA; Schema: public; Owner: davidhoupapa
--

COPY public.currency_rate (id, currency_id, pair, buy, date) FROM stdin;
1	1	USD	1.3198	2022-03-25 16:12:45.893887
2	1	AUD	1.7554	2022-03-25 16:12:45.896425
3	1	CZK	29.539	2022-03-25 16:12:45.89697
4	1	HKD	10.331	2022-03-25 16:12:45.897325
5	1	USD	1.3198	2022-03-25 16:12:58.190406
6	1	EUR	1.1986	2022-03-25 16:12:58.191977
7	1	AUD	1.7554	2022-03-25 16:12:58.192554
8	1	CZK	29.539	2022-03-25 16:12:58.193202
9	1	HKD	10.331	2022-03-25 16:12:58.193885
10	1	USD	1.3175	2022-03-25 16:30:33.726395
11	1	HKD	11.331	2022-03-26 12:35:55.167732
12	1	HKD	10.3365	2022-03-26 12:44:33.84476
13	1	USD	1.2631	2022-03-26 14:53:55.005075
14	3	USD	1.2631	2022-03-26 14:55:04.155586
15	5	HKD	0.58	2022-03-26 15:31:53.766847
16	5	HKD	1.7241	2022-03-26 15:33:59.977853
17	1	AUD	1.5384	2022-03-26 15:36:30.109761
\.


--
-- TOC entry 3676 (class 0 OID 19378)
-- Dependencies: 214
-- Data for Name: customer; Type: TABLE DATA; Schema: public; Owner: davidhoupapa
--

COPY public.customer (id, name) FROM stdin;
1	Customer 1
2	Customer 2
3	Customer 3
\.


--
-- TOC entry 3678 (class 0 OID 19404)
-- Dependencies: 216
-- Data for Name: customer_transaction; Type: TABLE DATA; Schema: public; Owner: davidhoupapa
--

COPY public.customer_transaction (id, customer_id, date, amount, currency_from, currency_to) FROM stdin;
1	1	2022-03-25 16:51:39.770191	100	GBP	USD
2	1	2022-03-26 11:46:38.478673	100	GBP	HKD
3	1	2022-03-26 12:28:00.326378	100	GBP	USD
4	1	2022-03-26 12:42:23.690393	100	GBP	HKD
5	1	2022-03-26 13:02:37.56468	100	GBP	USD
6	1	2022-03-26 13:11:05.572278	200	GBP	USD
8	1	2022-03-26 14:52:03.316084	1000	GBP	USD
9	1	2022-03-26 14:54:10.044585	100	GBP	USD
10	1	2022-03-26 14:55:37.088856	100	EUR	USD
11	1	2022-03-26 14:55:56.129725	500	EUR	USD
12	1	2022-03-26 15:27:36.656118	200	GBP	USD
13	1	2022-03-26 15:32:43.263689	300	CZK	HKD
14	1	2022-03-26 15:36:58.414016	200	GBP	AUD
15	1	2022-03-26 15:46:05.52805	200	GBP	AUD
16	1	2022-03-26 15:48:32.120447	200	GBP	AUD
17	1	2022-03-28 12:12:29.309137	300	CZK	HKD
18	1	2022-03-29 14:42:54.510503	200	GBP	USD
19	1	2022-03-29 14:43:08.398201	300	CZK	HKD
20	1	2022-03-29 14:58:12.113796	200	GBP	USD
21	1	2022-03-29 14:58:40.786013	100	EUR	USD
22	1	2022-03-29 14:58:57.281546	300	CZK	HKD
23	1	2022-03-29 15:05:14.785636	300	CZK	HKD
\.


--
-- TOC entry 3684 (class 0 OID 19485)
-- Dependencies: 226
-- Data for Name: fx_ledger; Type: TABLE DATA; Schema: public; Owner: davidhoupapa
--

COPY public.fx_ledger (id, fx_tran_id, date, currency, realised_fx, rate) FROM stdin;
2	18	2022-03-29 14:52:38.171414	CZK	0.34	0.03385354954466975862
3	19	2022-03-29 14:58:12.113796	GBP	5	0.79170295305201488402
4	20	2022-03-29 14:58:40.786013	EUR	3.96	0.79170295305201488402
5	21	2022-03-29 14:58:57.281546	CZK	5.80	0.58001276028072617598
6	22	2022-03-29 15:05:14.785636	CZK	0.34	0.03385354954466975862
\.


--
-- TOC entry 3681 (class 0 OID 19445)
-- Dependencies: 219
-- Data for Name: fx_transaction; Type: TABLE DATA; Schema: public; Owner: davidhoupapa
--

COPY public.fx_transaction (id, customer_id, transaction_id, date, fee, transaction_amount, amount_to_convert, converted, rate, currency_from, currency_to, deferred, currency_rate_id) FROM stdin;
1	1	1	2022-03-25 17:16:17.276792	5	100	95	120	1.3198	GBP	USD	f	1
12	1	12	2022-03-26 15:32:43.263689	10	300	290	168.20	0.58	CZK	HKD	f	2
14	1	15	2022-03-26 15:46:05.52805	5	200	195	299.9880	1.5384	GBP	AUD	f	3
3	1	3	2022-03-26 12:59:54.551738	5	100	95	981.9675	10.3365	GBP	HKD	f	4
5	1	5	2022-03-26 13:12:00.821747	5	200	195	256.9125	1.3175	GBP	USD	f	5
7	1	7	2022-03-26 14:52:03.316084	5	1000	995	1310.9125	1.3175	GBP	USD	f	6
8	1	8	2022-03-26 14:54:10.044585	5	100	95	119.9945	1.2631	GBP	USD	f	7
9	1	9	2022-03-26 14:55:37.088856	5	100	95	119.9945	1.2631	EUR	USD	f	8
10	1	10	2022-03-26 14:55:56.129725	5	500	495	625.2345	1.2631	EUR	USD	f	9
11	1	11	2022-03-26 15:27:36.656118	5	200	195	246.3045	1.2631	GBP	USD	f	10
15	1	16	2022-03-26 15:48:32.120447	5	200	195	299.9880	1.5384	GBP	AUD	t	11
13	1	13	2022-03-26 15:36:58.414016	5	200	195	303.0648	1.5384	GBP	AUD	f	12
16	1	17	2022-03-28 12:12:29.309137	10	300	290	499.9890	1.7241	CZK	HKD	f	16
17	1	18	2022-03-29 14:42:54.510503	5	200	195	246.3045	1.2631	GBP	USD	f	13
18	1	19	2022-03-29 14:43:08.398201	10	300	290	499.9890	1.7241	CZK	HKD	f	16
19	1	20	2022-03-29 14:58:12.113796	5	200	195	246.3045	1.2631	GBP	USD	f	13
20	1	21	2022-03-29 14:58:40.786013	5	100	95	119.9945	1.2631	EUR	USD	f	14
21	1	22	2022-03-29 14:58:57.281546	10	300	290	499.9890	1.7241	CZK	HKD	f	16
22	1	23	2022-03-29 15:05:14.785636	10	300	290	499.9890	1.7241	CZK	HKD	f	16
\.


--
-- TOC entry 3700 (class 0 OID 0)
-- Dependencies: 209
-- Name: currencies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.currencies_id_seq', 6, true);


--
-- TOC entry 3701 (class 0 OID 0)
-- Dependencies: 211
-- Name: currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.currency_rate_id_seq', 17, true);


--
-- TOC entry 3702 (class 0 OID 0)
-- Dependencies: 213
-- Name: customer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.customer_id_seq', 3, true);


--
-- TOC entry 3703 (class 0 OID 0)
-- Dependencies: 215
-- Name: customer_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.customer_transaction_id_seq', 23, true);


--
-- TOC entry 3704 (class 0 OID 0)
-- Dependencies: 225
-- Name: fx_ledger_fx_tran_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.fx_ledger_fx_tran_id_seq', 1, false);


--
-- TOC entry 3705 (class 0 OID 0)
-- Dependencies: 224
-- Name: fx_ledger_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.fx_ledger_id_seq', 6, true);


--
-- TOC entry 3706 (class 0 OID 0)
-- Dependencies: 227
-- Name: fx_transaction_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.fx_transaction_currency_rate_id_seq', 12, true);


--
-- TOC entry 3707 (class 0 OID 0)
-- Dependencies: 217
-- Name: fx_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.fx_transaction_id_seq', 22, true);


--
-- TOC entry 3708 (class 0 OID 0)
-- Dependencies: 218
-- Name: fx_transaction_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: davidhoupapa
--

SELECT pg_catalog.setval('public.fx_transaction_transaction_id_seq', 13, true);


--
-- TOC entry 3507 (class 2606 OID 19253)
-- Name: currencies currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currencies
    ADD CONSTRAINT currencies_pkey PRIMARY KEY (id);


--
-- TOC entry 3509 (class 2606 OID 19371)
-- Name: currency_rate currency_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currency_rate
    ADD CONSTRAINT currency_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 3511 (class 2606 OID 19383)
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (id);


--
-- TOC entry 3513 (class 2606 OID 19412)
-- Name: customer_transaction customer_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer_transaction
    ADD CONSTRAINT customer_transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 3517 (class 2606 OID 19494)
-- Name: fx_ledger fx_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger
    ADD CONSTRAINT fx_ledger_pkey PRIMARY KEY (id);


--
-- TOC entry 3515 (class 2606 OID 19454)
-- Name: fx_transaction fx_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction
    ADD CONSTRAINT fx_transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 3524 (class 2620 OID 19533)
-- Name: fx_transaction insert_fee_conversion; Type: TRIGGER; Schema: public; Owner: davidhoupapa
--

CREATE TRIGGER insert_fee_conversion AFTER INSERT ON public.fx_transaction FOR EACH ROW EXECUTE FUNCTION public.fee_conversion();


--
-- TOC entry 3523 (class 2620 OID 19460)
-- Name: customer_transaction insert_fx_conversion; Type: TRIGGER; Schema: public; Owner: davidhoupapa
--

CREATE TRIGGER insert_fx_conversion AFTER INSERT ON public.customer_transaction FOR EACH ROW EXECUTE FUNCTION public.fx_conversion();


--
-- TOC entry 3518 (class 2606 OID 19372)
-- Name: currency_rate currency_rate_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currency_rate
    ADD CONSTRAINT currency_rate_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.currencies(id);


--
-- TOC entry 3521 (class 2606 OID 19527)
-- Name: fx_transaction currency_rate_id; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction
    ADD CONSTRAINT currency_rate_id FOREIGN KEY (currency_rate_id) REFERENCES public.currency_rate(id) NOT VALID;


--
-- TOC entry 3519 (class 2606 OID 19413)
-- Name: customer_transaction customer_transaction_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer_transaction
    ADD CONSTRAINT customer_transaction_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(id);


--
-- TOC entry 3520 (class 2606 OID 19500)
-- Name: fx_transaction customer_transaction_id; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction
    ADD CONSTRAINT customer_transaction_id FOREIGN KEY (transaction_id) REFERENCES public.customer_transaction(id) NOT VALID;


--
-- TOC entry 3522 (class 2606 OID 19495)
-- Name: fx_ledger fx_transaction_id; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger
    ADD CONSTRAINT fx_transaction_id FOREIGN KEY (fx_tran_id) REFERENCES public.fx_transaction(id) NOT VALID;


-- Completed on 2022-03-29 16:46:08 BST

--
-- PostgreSQL database dump complete
--
-- Additional Inserts
INSERT INTO customer(name) VALUES ('Customer 1');
INSERT INTO customer(name) VALUES ('Customer 2');
INSERT INTO customer(name) VALUES ('Customer 3');

INSERT INTO currencies (currency,name) VALUES ('GBP','British Pound');
INSERT INTO currencies (currency,name) VALUES ('USD','US Dollar');
INSERT INTO currencies (currency,name) VALUES ('EUR','Euro');
INSERT INTO currencies (currency,name) VALUES ('AUD','Australian Dollar');
INSERT INTO currencies (currency,name) VALUES ('CZK','Czech Koruna');
INSERT INTO currencies (currency,name) VALUES ('HKD','Hong Kong Dollars');

INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'USD',1.3198);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'EUR',1.1986);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'AUD',1.7554);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'CZK',29.539);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'HKD',10.331);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'USD',1.3175);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'HKD',10.3365);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'USD',1.2631);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (3,'USD',1.2631);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (5,'HKD',1.7241);
INSERT INTO currency_rate (currency_id,pair,buy) VALUES (1,'AUD',1.5384);


INSERT INTO customer_transaction (customer_id,amount,currency_from,currency_to) VALUES (1,200,'GBP','USD');
INSERT INTO customer_transaction (customer_id,amount,currency_from,currency_to) VALUES (1,100,'GBP','HKD');
INSERT INTO customer_transaction (customer_id,amount,currency_from,currency_to) VALUES (1,100,'EUR','USD');
INSERT INTO customer_transaction (customer_id,amount,currency_from,currency_to) VALUES (1,300,'CZK','HKD');
INSERT INTO customer_transaction (customer_id,amount,currency_from,currency_to) VALUES (1,200,'GBP','AUD');

UPDATE fx_transaction SET deferred = TRUE WHERE transaction_id = 3;
