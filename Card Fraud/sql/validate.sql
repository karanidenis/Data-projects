-- Data validation / profiling queries, run against the loaded tables.
-- Usage:
--   docker compose exec -T db psql -U fraud -d fraud -f /dev/stdin < sql/02_validate.sql
-- or interactively:
--   psql -h localhost -p 5433 -U fraud -d fraud
--   \i sql/02_validate.sql

-- A. Row counts
SELECT 'users' AS table_name, count(*) FROM users
UNION ALL SELECT 'recipients', count(*) FROM recipients
UNION ALL SELECT 'login_events', count(*) FROM login_events
UNION ALL SELECT 'transactions', count(*) FROM transactions;

--   table_name  | count 
-- --------------+-------
--  users        |   800
--  recipients   |  1621
--  login_events | 17631
--  transactions | 17923

-- B. Primary key uniqueness
SELECT 'users.user_id dup' AS check, user_id, count(*)
FROM users GROUP BY user_id HAVING count(*) > 1;

SELECT 'recipients.recipient_id dup' AS check, recipient_id, count(*)
FROM recipients GROUP BY recipient_id HAVING count(*) > 1;

SELECT 'transactions.transaction_id dup' AS check, transaction_id, count(*)
FROM transactions GROUP BY transaction_id HAVING count(*) > 1;

-- C. Null checks on columns that should always be populated
SELECT 'users' AS table_name,
    count(*) FILTER (WHERE user_id IS NULL)           AS null_user_id,
    count(*) FILTER (WHERE signup_ts IS NULL)          AS null_signup_ts,
    count(*) FILTER (WHERE residence_country IS NULL)  AS null_residence_country,
    count(*) FILTER (WHERE kyc_level IS NULL)           AS null_kyc_level
FROM users;

SELECT 'recipients' AS table_name,
    count(*) FILTER (WHERE recipient_id IS NULL)   AS null_recipient_id,
    count(*) FILTER (WHERE created_ts IS NULL)     AS null_created_ts,
    count(*) FILTER (WHERE receive_country IS NULL) AS null_receive_country
FROM recipients;

SELECT 'login_events' AS table_name,
    count(*) FILTER (WHERE user_id IS NULL)   AS null_user_id,
    count(*) FILTER (WHERE login_ts IS NULL)  AS null_login_ts,
    count(*) FILTER (WHERE device_id IS NULL) AS null_device_id,
    count(*) FILTER (WHERE ip_address IS NULL) AS null_ip_address
FROM login_events;

SELECT 'transactions' AS table_name,
    count(*) FILTER (WHERE transaction_id IS NULL) AS null_transaction_id,
    count(*) FILTER (WHERE user_id IS NULL)         AS null_user_id,
    count(*) FILTER (WHERE recipient_id IS NULL)    AS null_recipient_id,
    count(*) FILTER (WHERE send_amount IS NULL)     AS null_send_amount,
    count(*) FILTER (WHERE fx_rate IS NULL)          AS null_fx_rate,
    count(*) FILTER (WHERE status IS NULL)           AS null_status
FROM transactions;

-- D. Referential integrity
SELECT 'transactions.user_id not in users' AS check, count(*)
FROM transactions t LEFT JOIN users u ON t.user_id = u.user_id
WHERE u.user_id IS NULL;

SELECT 'transactions.recipient_id not in recipients' AS check, count(*)
FROM transactions t LEFT JOIN recipients r 
ON t.recipient_id = r.recipient_id
WHERE r.recipient_id IS NULL;

SELECT 'login_events.user_id not in users' AS check, count(*)
FROM login_events l LEFT JOIN users u ON l.user_id = u.user_id
WHERE u.user_id IS NULL;

-- E. Domain / categorical value checks — eyeball for typos or
--    unexpected categories before building features on them
SELECT 'users.kyc_level' AS column, kyc_level AS value, count(*) FROM users GROUP BY kyc_level ORDER BY 3 DESC;
--      column      | value | count 
-- -----------------+-------+-------
--  users.kyc_level | full  |   606
--  users.kyc_level | basic |   194
SELECT 'users.signup_channel' AS column, signup_channel AS value, count(*) FROM users GROUP BY signup_channel ORDER BY 3 DESC;
--         column        |    value    | count 
-- ----------------------+-------------+-------
--  users.signup_channel | ios_app     |   410
--  users.signup_channel | android_app |   321
--  users.signup_channel | web         |    69
SELECT 'recipients.payout_method' AS column, payout_method AS value, count(*) FROM recipients GROUP BY payout_method ORDER BY 3 DESC;
--           column          |    value     | count 
-- --------------------------+--------------+-------
--  recipients.payout_method | bank         |   650
--  recipients.payout_method | mpesa        |   319
--  recipients.payout_method | mtn_momo     |   306
--  recipients.payout_method | tigopesa     |   187
--  recipients.payout_method | airtel_money |   159
SELECT 'login_events.os' AS column, os AS value, count(*) FROM login_events GROUP BY os ORDER BY 3 DESC;
--      column      |  value  | count 
-- -----------------+---------+-------
--  login_events.os | Android |  8870
--  login_events.os | iOS     |  8761
SELECT 'login_events.auth_method' AS column, auth_method AS value, count(*) FROM login_events GROUP BY auth_method ORDER BY 3 DESC;
--           column          |   value   | count 
-- --------------------------+-----------+-------
--  login_events.auth_method | pin       |  5941
--  login_events.auth_method | password  |  5858
--  login_events.auth_method | biometric |  5832
-- (3 rows)
SELECT 'login_events.login_success' AS column, login_success AS value, count(*) FROM login_events GROUP BY login_success ORDER BY 3 DESC;
--            column           | value | count 
-- ----------------------------+-------+-------
--  login_events.login_success |     1 | 17549
--  login_events.login_success |     0 |    82
-- (2 rows)
SELECT 'transactions.status' AS column, status AS value, count(*) FROM transactions GROUP BY status ORDER BY 3 DESC;
--        column        |   value   | count 
-- ---------------------+-----------+-------
--  transactions.status | completed | 17191
--  transactions.status | failed    |   732
-- (2 rows)
SELECT 'transactions.decline_reason' AS column, decline_reason AS value, count(*) FROM transactions GROUP BY decline_reason ORDER BY 3 DESC;
--            column            |         value         | count 
-- -----------------------------+-----------------------+-------
--  transactions.decline_reason |                       | 17191
--  transactions.decline_reason | card_declined         |   319
--  transactions.decline_reason | payout_provider_error |   218
--  transactions.decline_reason | insufficient_funds    |   195
SELECT 'transactions.payment_method' AS column, payment_method AS value, count(*) FROM transactions GROUP BY payment_method ORDER BY 3 DESC;
--            column            |     value     | count 
-- -----------------------------+---------------+-------
--  transactions.payment_method | debit_card    |  8959
--  transactions.payment_method | bank_transfer |  5522
--  transactions.payment_method | apple_pay     |  2120
--  transactions.payment_method | google_pay    |  1322
SELECT 'transactions.payout_method' AS column, payout_method AS value, count(*) FROM transactions GROUP BY payout_method ORDER BY 3 DESC;
--            column           |    value     | count 
-- ----------------------------+--------------+-------
--  transactions.payout_method | bank         |  7291
--  transactions.payout_method | mpesa        |  3548
--  transactions.payout_method | mtn_momo     |  3433
--  transactions.payout_method | airtel_money |  1870
--  transactions.payout_method | tigopesa     |  1781
-- (5 rows)
SELECT 'transactions.send_currency' AS column, send_currency AS value, count(*) FROM transactions GROUP BY send_currency ORDER BY 3 DESC;
--            column           | value | count 
-- ----------------------------+-------+-------
--  transactions.send_currency | GBP   |  9765
--  transactions.send_currency | USD   |  5058
--  transactions.send_currency | EUR   |  3100
-- (3 rows)
SELECT 'transactions.receive_currency' AS column, receive_currency AS value, count(*) FROM transactions GROUP BY receive_currency ORDER BY 3 DESC;
--             column             | value | count 
-- -------------------------------+-------+-------
--  transactions.receive_currency | GHS   |  3759
--  transactions.receive_currency | TZS   |  3623
--  transactions.receive_currency | NGN   |  3589
--  transactions.receive_currency | KES   |  3494
--  transactions.receive_currency | UGX   |  3458


-- F. Numeric range sanity checks (should return 0 rows)
SELECT 'send_amount <= 0' AS check, count(*) FROM transactions WHERE send_amount <= 0;
SELECT 'receive_amount <= 0' AS check, count(*) FROM transactions WHERE receive_amount <= 0;
SELECT 'fx_rate <= 0' AS check, count(*) FROM transactions WHERE fx_rate <= 0;
SELECT 'fee_amount < 0' AS check, count(*) FROM transactions WHERE fee_amount < 0;
SELECT 'birth_year out of plausible range' AS check, count(*)
FROM users WHERE birth_year < 1930 OR birth_year > extract(year FROM now()) - 13;

-- G. Timestamp ordering sanity checks (should return 0 rows)
SELECT 'kyc_verified_ts before signup_ts' AS check, count(*)
FROM users WHERE kyc_verified_ts IS NOT NULL AND kyc_verified_ts::timestamp < signup_ts::timestamp;

SELECT 'transaction before user signup' AS check, count(*)
FROM transactions t JOIN users u ON t.user_id = u.user_id
WHERE t.created_ts::timestamp < u.signup_ts::timestamp;

SELECT 'transaction before recipient created' AS check, count(*)
FROM transactions t JOIN recipients r ON t.recipient_id = r.recipient_id
WHERE t.created_ts::timestamp < r.created_ts::timestamp;
--                 check                 | count 
-- --------------------------------------+-------
--  transaction before recipient created |  4414


-- H. status / decline_reason consistency (should return 0 rows)
SELECT 'completed txn with decline_reason set' AS check, count(*)
FROM transactions WHERE status = 'completed' AND decline_reason IS NOT NULL;

SELECT 'failed txn with no decline_reason' AS check, count(*)
FROM transactions WHERE status = 'failed' AND decline_reason IS NULL;
