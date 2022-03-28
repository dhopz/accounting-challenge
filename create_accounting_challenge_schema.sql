--
-- PostgreSQL database dump
--

-- Dumped from database version 14.0
-- Dumped by pg_dump version 14.2

-- Started on 2022-03-28 13:03:42 BST

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
-- TOC entry 3659 (class 1262 OID 19246)
-- Name: accounting_challenge; Type: DATABASE; Schema: -; Owner: davidhoupapa
--

CREATE DATABASE accounting_challenge WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'C';


ALTER DATABASE accounting_challenge OWNER TO davidhoupapa;

\connect accounting_challenge

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
-- TOC entry 231 (class 1255 OID 19459)
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
-- TOC entry 3660 (class 0 OID 0)
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
-- TOC entry 3661 (class 0 OID 0)
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
-- TOC entry 3662 (class 0 OID 0)
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
-- TOC entry 3663 (class 0 OID 0)
-- Dependencies: 215
-- Name: customer_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.customer_transaction_id_seq OWNED BY public.customer_transaction.id;


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
-- TOC entry 226 (class 1259 OID 19485)
-- Name: fx_ledger; Type: TABLE; Schema: public; Owner: davidhoupapa
--

CREATE TABLE public.fx_ledger (
    id integer NOT NULL,
    fx_tran_id integer NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    currency character varying(3),
    unrealised_fx numeric,
    realised_fx numeric
);


ALTER TABLE public.fx_ledger OWNER TO davidhoupapa;

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
-- TOC entry 3664 (class 0 OID 0)
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
-- TOC entry 3665 (class 0 OID 0)
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
-- TOC entry 3666 (class 0 OID 0)
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
-- TOC entry 3667 (class 0 OID 0)
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
-- TOC entry 3668 (class 0 OID 0)
-- Dependencies: 218
-- Name: fx_transaction_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: davidhoupapa
--

ALTER SEQUENCE public.fx_transaction_transaction_id_seq OWNED BY public.fx_transaction.transaction_id;


--
-- TOC entry 3476 (class 2604 OID 19251)
-- Name: currencies id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currencies ALTER COLUMN id SET DEFAULT nextval('public.currencies_id_seq'::regclass);


--
-- TOC entry 3477 (class 2604 OID 19365)
-- Name: currency_rate id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currency_rate ALTER COLUMN id SET DEFAULT nextval('public.currency_rate_id_seq'::regclass);


--
-- TOC entry 3480 (class 2604 OID 19381)
-- Name: customer id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer ALTER COLUMN id SET DEFAULT nextval('public.customer_id_seq'::regclass);


--
-- TOC entry 3481 (class 2604 OID 19407)
-- Name: customer_transaction id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer_transaction ALTER COLUMN id SET DEFAULT nextval('public.customer_transaction_id_seq'::regclass);


--
-- TOC entry 3490 (class 2604 OID 19488)
-- Name: fx_ledger id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger ALTER COLUMN id SET DEFAULT nextval('public.fx_ledger_id_seq'::regclass);


--
-- TOC entry 3491 (class 2604 OID 19489)
-- Name: fx_ledger fx_tran_id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger ALTER COLUMN fx_tran_id SET DEFAULT nextval('public.fx_ledger_fx_tran_id_seq'::regclass);


--
-- TOC entry 3484 (class 2604 OID 19448)
-- Name: fx_transaction id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction ALTER COLUMN id SET DEFAULT nextval('public.fx_transaction_id_seq'::regclass);


--
-- TOC entry 3485 (class 2604 OID 19449)
-- Name: fx_transaction transaction_id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction ALTER COLUMN transaction_id SET DEFAULT nextval('public.fx_transaction_transaction_id_seq'::regclass);


--
-- TOC entry 3489 (class 2604 OID 19520)
-- Name: fx_transaction currency_rate_id; Type: DEFAULT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction ALTER COLUMN currency_rate_id SET DEFAULT nextval('public.fx_transaction_currency_rate_id_seq'::regclass);


--
-- TOC entry 3494 (class 2606 OID 19253)
-- Name: currencies currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currencies
    ADD CONSTRAINT currencies_pkey PRIMARY KEY (id);


--
-- TOC entry 3496 (class 2606 OID 19371)
-- Name: currency_rate currency_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currency_rate
    ADD CONSTRAINT currency_rate_pkey PRIMARY KEY (id);


--
-- TOC entry 3498 (class 2606 OID 19383)
-- Name: customer customer_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer
    ADD CONSTRAINT customer_pkey PRIMARY KEY (id);


--
-- TOC entry 3500 (class 2606 OID 19412)
-- Name: customer_transaction customer_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer_transaction
    ADD CONSTRAINT customer_transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 3504 (class 2606 OID 19494)
-- Name: fx_ledger fx_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger
    ADD CONSTRAINT fx_ledger_pkey PRIMARY KEY (id);


--
-- TOC entry 3502 (class 2606 OID 19454)
-- Name: fx_transaction fx_transaction_pkey; Type: CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction
    ADD CONSTRAINT fx_transaction_pkey PRIMARY KEY (id);


--
-- TOC entry 3510 (class 2620 OID 19460)
-- Name: customer_transaction insert_fx_conversion; Type: TRIGGER; Schema: public; Owner: davidhoupapa
--

CREATE TRIGGER insert_fx_conversion AFTER INSERT ON public.customer_transaction FOR EACH ROW EXECUTE FUNCTION public.fx_conversion();


--
-- TOC entry 3505 (class 2606 OID 19372)
-- Name: currency_rate currency_rate_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.currency_rate
    ADD CONSTRAINT currency_rate_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.currencies(id);


--
-- TOC entry 3508 (class 2606 OID 19527)
-- Name: fx_transaction currency_rate_id; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction
    ADD CONSTRAINT currency_rate_id FOREIGN KEY (currency_rate_id) REFERENCES public.currency_rate(id) NOT VALID;


--
-- TOC entry 3506 (class 2606 OID 19413)
-- Name: customer_transaction customer_transaction_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.customer_transaction
    ADD CONSTRAINT customer_transaction_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customer(id);


--
-- TOC entry 3507 (class 2606 OID 19500)
-- Name: fx_transaction customer_transaction_id; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_transaction
    ADD CONSTRAINT customer_transaction_id FOREIGN KEY (transaction_id) REFERENCES public.customer_transaction(id) NOT VALID;


--
-- TOC entry 3509 (class 2606 OID 19495)
-- Name: fx_ledger fx_transaction_id; Type: FK CONSTRAINT; Schema: public; Owner: davidhoupapa
--

ALTER TABLE ONLY public.fx_ledger
    ADD CONSTRAINT fx_transaction_id FOREIGN KEY (fx_tran_id) REFERENCES public.fx_transaction(id) NOT VALID;


-- Completed on 2022-03-28 13:03:42 BST

--
-- PostgreSQL database dump complete
--

