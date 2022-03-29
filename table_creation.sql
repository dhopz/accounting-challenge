CREATE TABLE customer_transaction (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    amount DECIMAL NOT NULL,
    currency_from VARCHAR (3) NOT NULL,
    currency_to VARCHAR (3) NOT NULL,
    pair VARCHAR(6) GENERATED ALWAYS AS (currency_from || currency_to) STORED,
    FOREIGN KEY (customer_id)
        REFERENCES customer (id)   
);

CREATE TABLE fx_transaction (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER,
    transaction_id SERIAL,
    currency_rate_id SERIAL,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    fee DECIMAL NOT NULL DEFAULT 5,
    transaction_amount DECIMAL NOT NULL,
    amount_to_convert DECIMAL NOT NULL,
    converted DECIMAL NOT NULL,
    rate DECIMAL NOT NULL,
    currency_from VARCHAR (3) NOT NULL,
    currency_to VARCHAR (3) NOT NULL,
    pair VARCHAR(6) GENERATED ALWAYS AS (currency_from || currency_to) STORED;
    deferred BOOLEAN DEFAULT FALSE,
);

ALTER TABLE fx_transaction
ADD COLUMN currency_rate_id SERIAL;

CREATE TABLE currencies (
    id SERIAL PRIMARY KEY,
    currency VARCHAR (3),
    name VARCHAR (20),
    fee DECIMAL,
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

UPDATE fx_transaction SET deferred = TRUE WHERE transaction_id = 16;


CREATE OR REPLACE VIEW fx_table AS
SELECT currency,pair,buy,sell,date,CONCAT(currency,pair) AS currency_pair
FROM currency_rate 
INNER JOIN currencies ON currencies.id = currency_rate.currency_id;

CREATE OR REPLACE VIEW cust_tran AS
SELECT 
t1.customer_id,
t1.amount,
t3.fee,
t1.amount - t3.fee AS amount_to_convert,
(t1.amount - t3.fee) * t2.buy AS converted,
t2.buy AS buy_rate,
t1.currency_from,
t1.currency_to
FROM
    (SELECT *,CONCAT(currency_from,currency_to) AS currency_pair FROM customer_transaction ORDER BY date DESC LIMIT 1) t1
LEFT JOIN 
    (SELECT buy,sell,currency_pair FROM fx_table ORDER BY date DESC) t2 
ON (t2.currency_pair = t1.currency_pair)
LEFT JOIN
    currencies t3
ON (t1.currency_from = t3.currency)
ORDER BY date DESC LIMIT 1;

INSERT INTO
fx_transaction(
    customer_id,
    transaction_amount,
    fee,
    amount_to_convert,
    converted,
    rate,
    currency_rate_id,
    currency_from,
    currency_to) 
SELECT 
t1.customer_id,
t1.amount,
t3.fee,
t1.amount - t3.fee AS amount_to_convert,
(t1.amount - t3.fee) * t2.buy AS converted,
t2.buy AS buy_rate,
t2.id AS currency_rate_id,
t1.currency_from,
t1.currency_to
FROM
    (SELECT *,CONCAT(currency_from,currency_to) AS currency_pair FROM customer_transaction ORDER BY date DESC LIMIT 1) t1
LEFT JOIN 
    (SELECT id,buy,sell,currency_pair FROM fx_table ORDER BY date DESC) t2 
ON (t2.currency_pair = t1.currency_pair)
LEFT JOIN
    currencies t3
ON (t1.currency_from = t3.currency)
ORDER BY date DESC LIMIT 1;

CREATE OR REPLACE FUNCTION fx_conversion() RETURNS TRIGGER AS
$BODY$
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
$BODY$
language plpgsql;

CREATE TRIGGER insert_fx_conversion
     AFTER INSERT ON customer_transaction
     FOR EACH ROW
     EXECUTE PROCEDURE fx_conversion();

CREATE OR REPLACE VIEW e1_accounts AS
SELECT
    currency_from AS currency,
    SUM(transaction_amount) AS cash,
    SUM(-amount_to_convert) AS customer_liability,
    SUM(CASE deferred
        WHEN 'FALSE' THEN -fee
        END) AS revenue,
    SUM(CASE deferred
        WHEN 'TRUE' THEN -fee
        END) AS intercompany_payable
FROM fx_transaction
GROUP BY currency_from;

CREATE OR REPLACE VIEW e2_accounts AS
SELECT
    currency_from AS currency,
    SUM(transaction_amount) AS cash,
    SUM(-amount_to_convert) AS customer_liability,
    SUM(CASE deferred
        WHEN 'FALSE' THEN -fee
        END) AS revenue,
    SUM(CASE deferred
        WHEN 'TRUE' THEN fee 
        END) AS intercompany_receivable
FROM fx_transaction
GROUP BY currency_from;

CREATE TABLE fx_ledger (
    id SERIAL PRIMARY KEY,
    fx_tran_id SERIAL,
    date TIMESTAMP NOT NULL DEFAULT NOW(),
    currency VARCHAR (3),
    unrealised_fx DECIMAL,
    realised_fx DECIMAL
);

CREATE OR REPLACE FUNCTION fee_conversion() RETURNS TRIGGER AS
$BODY$
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
$BODY$
language plpgsql;

CREATE TRIGGER insert_fee_conversion
     AFTER INSERT ON fx_transaction
     FOR EACH ROW
     EXECUTE PROCEDURE fee_conversion();

CREATE OR REPLACE VIEW fx_realised AS
SELECT SUM(realised_fx) AS realized_fx, 'GBP' AS reporting_currency FROM fx_ledger
WHERE currency != 'GBP';

CREATE OR REPLACE VIEW fx_accounts AS
SELECT cash,customer_liability,revenue,intercompany_payable,realized_fx FROM e1_accounts
INNER JOIN fx_realised
ON fx_realised.reporting_currency = e1_accounts.currency;

CREATE OR REPLACE VIEW accounts AS
SELECT                            
   unnest(array['cash','customer_liability','revenue','intercompany_payable','realized_fx']) AS "Ledger",
   unnest(array[cash,customer_liability,revenue,intercompany_payable,realized_fx]) AS "GBP"
FROM fx_accounts;          





