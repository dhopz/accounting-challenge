CREATE TABLE E1_accounts (
    unique_id TEXT NOT NULL DEFAULT 'PREFIX'||to_char(nextval('my_prefixed_seq'::regclass), 'A'), 
    cash DECIMAL,
    customer_liability DECIMAL,
    revenue DECIMAL,
    intercompany_payable DECIMAL,
    intercompany_receivable DECIMAL,
    unrealized_fx DECIMAL,
    currency VARCHAR (15),
    );

CREATE TABLE E2_accounts (
    unique_id TEXT NOT NULL DEFAULT 'PREFIX'||to_char(nextval('my_prefixed_seq'::regclass), 'A'), 
    cash DECIMAL,
    customer_liability DECIMAL,
    revenue DECIMAL,
    intercompany_payable DECIMAL,
    intercompany_receivable DECIMAL,
    unrealized_fx DECIMAL,
    currency VARCHAR (15),
    );

CREATE TABLE entities (
    id SERIAL PRIMARY KEY,
    name VARCHAR (50)
)

CREATE TABLE customer_transaction (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    amount DECIMAL NOT NULL,
    currency_from VARCHAR (3) NOT NULL,
    currency_to VARCHAR (3) NOT NULL,
    FOREIGN KEY (customer_id)
        REFERENCES customer (id)   
);

CREATE TABLE fx_transaction (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    transaction_id SERIAL,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    fee DECIMAL NOT NULL DEFAULT 5,
    transaction_amount DECIMAL NOT NULL,
    amount_to_convert DECIMAL NOT NULL,
    converted DECIMAL NOT NULL,
    rate DECIMAL NOT NULL,
    currency_from VARCHAR (3) NOT NULL,
    currency_to VARCHAR (3) NOT NULL
);

CREATE TABLE currencies (
    id SERIAL PRIMARY KEY,
    currency VARCHAR (3),
    name VARCHAR (20)
);

CREATE TABLE currency_rate (
    id SERIAL PRIMARY KEY,
    currency_id INT NOT NULL,
    pair VARCHAR (3),
    buy DECIMAL,
    sell DECIMAL NOT NULL GENERATED ALWAYS AS (1 / buy) STORED,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (currency_id)
        REFERENCES currencies (id)
);

CREATE TABLE customer (
    id SERIAL PRIMARY KEY,
    name VARCHAR (20)
);

CREATE TRIGGER post_transaction
    AFTER UPDATE ON transactions
    FOR EACH ROW
    EXECUTE PROCEDURE check_account_update();

-- how to deal with reversals, probably an update trigger and a query
-- how to deal with revaluation, possible an update trigger
-- how to deal with deferred, 

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

CREATE OR REPLACE VIEW fx_table AS
SELECT currency,pair,buy,sell,date,CONCAT(currency,pair) AS currency_pair
FROM currency_rate 
INNER JOIN currencies ON currencies.id = currency_rate.currency_id;

SELECT * FROM fx_table;

SELECT * FROM fx_table 
WHERE currency = 'GBP' AND pair = 'USD'
ORDER BY date 
DESC LIMIT 1;

INSERT INTO customer_transaction (customer_id,amount,currency_from,currency_to) VALUES (1,100,'GBP','USD');
INSERT INTO fx_transaction(customer_id,transaction_amount,amount_to_convert,converted,rate,currency_from,currency_to) VALUES(1,100,95,120,1.3198,'GBP','USD');

transaction_amount DECIMAL NOT NULL,
    amount_to_convert DECIMAL NOT NULL,
    converted DEC


CREATE OR REPLACE FUNCTION convert_fx() RETURNS TRIGGER AS
$BODY$
BEGIN
    INSERT INTO
        fx_transaction(customer_id,converted_funds,rate,currency_from,currency_to)
        VALUES(new.id,new.name);

           RETURN new;
END;
$BODY$
language plpgsql;

WITH buy_rate as (
    SELECT * FROM fx_table 
    WHERE currency = 'GBP' AND pair = 'USD'
    ORDER BY date 
    DESC LIMIT 1),
select * from table_3 where column_1 = (select value_1 from v1) 
and column_2 = (select value_2 from v2);


SELECT *,CONCAT(currency_from,currency_to) AS currency_pair FROM customer_transaction;

SELECT * FROM fx_table 
ORDER BY date 
DESC LIMIT 1;

SELECT *,customer_id,amount,CONCAT(currency_from,currency_to) AS currency_pair FROM customer_transaction t1
INNER JOIN (
    SELECT * FROM fx_table 
    ORDER BY date 
    DESC LIMIT 1) t2 
ON t2.currency_pair = t2.currency_pair;