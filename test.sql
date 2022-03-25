CREATE TABLE table1
(
  id integer NOT NULL,
  name character varying,
  CONSTRAINT table1_pkey PRIMARY KEY (id)
);

CREATE TABLE table2
(
  id integer NOT NULL,
  name character varying
);

CREATE OR REPLACE FUNCTION function_copy() RETURNS TRIGGER AS
$BODY$
BEGIN
    INSERT INTO
        table2(id,name)
        VALUES(new.id,new.name);

           RETURN new;
END;
$BODY$
language plpgsql;

CREATE TRIGGER trig_copy
     AFTER INSERT ON table1
     FOR EACH ROW
     EXECUTE PROCEDURE function_copy();

INSERT INTO table1 (id,name)
VALUES ('1','John');

INSERT INTO table2 (id,name)
VALUES ('2','Jimbo');

INSERT INTO table1 (id,name)
VALUES ('2','Max');