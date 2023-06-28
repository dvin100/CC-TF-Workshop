
SET 'auto.offset.reset' = 'earliest';

CREATE STREAM transactions_raw WITH (
    KAFKA_TOPIC = 'transactions',
    VALUE_FORMAT = 'AVRO'
);

CREATE STREAM TRANSACTIONS_FORMATED
WITH (KAFKA_TOPIC='TRANSACTIONS_FORMATED', PARTITIONS=6, REPLICAS=3) as 
select 
TRANSACTION_ID, cast(CARD_ID as STRING) as CARD_ID, USER_ID, cast(STORE_ID as STRING) as STORE_ID
from TRANSACTIONS_RAW 
where USER_ID != 'User_'
EMIT CHANGES;


CREATE STREAM USERS_STREAM WITH (KAFKA_TOPIC ='cc-workshop.creditcards.users', KEY_FORMAT  ='JSON', VALUE_FORMAT='AVRO');
CREATE TABLE USERS WITH (FORMAT='AVRO') AS
     SELECT userid,                     
        LATEST_BY_OFFSET(name) AS name,
        LATEST_BY_OFFSET(phone) AS phone
     FROM USERS_STREAM
 GROUP BY userid;


CREATE STREAM CARDS_STREAM WITH (KAFKA_TOPIC ='cc-workshop.creditcards.cards', KEY_FORMAT  ='JSON', VALUE_FORMAT='AVRO');
CREATE TABLE CARDS WITH (FORMAT='AVRO') AS
     SELECT CARD_ID,                     
        LATEST_BY_OFFSET(number) AS number,
        LATEST_BY_OFFSET(CVV) AS CVV,
        LATEST_BY_OFFSET(EXPIRATION) AS EXPIRATION
     FROM CARDS_STREAM
 GROUP BY CARD_ID;

CREATE STREAM STORES_STREAM WITH (KAFKA_TOPIC ='cc-workshop.creditcards.stores', KEY_FORMAT  ='JSON', VALUE_FORMAT='AVRO');
CREATE TABLE STORES WITH (FORMAT='AVRO') AS
     SELECT STORE_ID,                     
        LATEST_BY_OFFSET(NAME) AS NAME,
        LATEST_BY_OFFSET(STATE) AS STATE
     FROM STORES_STREAM
 GROUP BY STORE_ID;


CREATE STREAM TRANSACTIONS_FULL
WITH (KAFKA_TOPIC='TRANSACTION_FULL', PARTITIONS=6, REPLICAS=3) as 
select 
 T.TRANSACTION_ID as TRANSACTION_ID,
 T.CARD_ID as CARD_ID,
 T.USER_ID as USER_ID,
 T.STORE_ID as STORE_ID,
 U.NAME as CLIENT_NAME,
 U.PHONE as CLIENT_PHONE,
 C.NUMBER as CARD_NUMBER,
 S.NAME as STORE_NAME,
 S.STATE as STORE_STATE
from TRANSACTIONS_FORMATED T
left join USERS U
on T.USER_ID=U.USERID
left join CARDS C
on T.CARD_ID = C.CARD_ID
left join STORES S
on T.STORE_ID = S.STORE_ID
EMIT CHANGES;


CREATE TABLE FRAUD
WITH (KAFKA_TOPIC='FRAUD', PARTITIONS=6, REPLICAS=3) as 
select CARD_NUMBER, COUNT(*) as TX_CNT, COLLECT_SET(STORE_STATE) as STATES
from TRANSACTIONS_FULL 
WINDOW TUMBLING (SIZE 60 seconds)
group by CARD_NUMBER
having COUNT(*)>2
EMIT CHANGES;