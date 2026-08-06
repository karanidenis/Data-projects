-- Exploring how the tables join together before committing to a feature view.
-- The goal is to understand the relationships between users, transactions, recipients, 
--   and login events, and to identify potential features for fraud detection.

-- Run interactively:
--   psql -h localhost -p 5433 -U fraud -d fraudSELECT * FROM users LIMIT 5;
SELECT count(*) FROM users; -- 800
SELECT * FROM recipients LIMIT 5;
SELECT count(*) FROM recipients; -- 1621
SELECT * FROM transactions LIMIT 2;
SELECT count(*) FROM transactions; --  17923
SELECT * FROM login_events LIMIT 5;
SELECT count(*) FROM login_events; -- 17631

-- Table relationships:
--   users (1) ----< transactions >---- (1) recipients
--   users (1) ----< login_events

-- transactions.user_id      -> users.user_id
-- transactions.recipient_id -> recipients.recipient_id
-- login_events.user_id      -> users.user_id

-- 1. One row per transaction with sender(user) + recipient context.
--    Check this returns the same row count as `SELECT count(*) FROM transactions`
--    (inner joins here should not drop or duplicate rows given the FK checks passed).
SELECT count(*) FROM transactions t
JOIN users u ON t.user_id = u.user_id
JOIN recipients r ON t.recipient_id = r.recipient_id; 

-- 17923 columns, 1 row per transaction, as expected.


-- 2. Does the transaction's IP country match the user's most recent login
--    IP country before the transaction? A mismatch is a classic fraud signal.
--    LATERAL join = correlated subquery, re-run per transaction row.
SELECT
    t.transaction_id, t.ip_country AS txn_ip_country,
    l.ip_country AS last_login_ip_country, l.login_ts AS last_login_ts,
    (t.ip_country IS DISTINCT FROM l.ip_country) AS ip_country_mismatch
FROM transactions t
LEFT JOIN LATERAL (
    SELECT ip_country, login_ts
    FROM login_events le
    WHERE le.user_id = t.user_id AND le.login_epoch <= t.created_epoch
    ORDER BY le.login_epoch DESC
    LIMIT 1
) l ON true
ORDER BY t.created_epoch
LIMIT 10;

--  transaction_id | txn_ip_country | last_login_ip_country |    last_login_ts    | ip_country_mismatch 
-- ----------------+----------------+-----------------------+---------------------+---------------------
--  T0006626       | GB             | GB                    | 2026-01-01 06:02:45 | f
--  T0014204       | GB             | GB                    | 2026-01-01 06:04:07 | f
--  T0015784       | GB             | GB                    | 2026-01-01 06:20:38 | f
--  T0011544       | US             | US                    | 2026-01-01 06:32:35 | f
--  T0002059       | GB             | GB                    | 2026-01-01 06:32:17 | f
--  T0009222       | DE             | DE                    | 2026-01-01 06:46:34 | f
--  T0002441       | GB             | GB                    | 2026-01-01 06:44:23 | f
--  T0007937       | GB             | GB                    | 2026-01-01 06:48:12 | f
--  T0011290       | GB             | GB                    | 2026-01-01 06:52:08 | f
--  T0009808       | US             | US                    | 2026-01-01 07:23:17 | f
-- (10 rows)



-- 3. Transaction velocity: how many transactions has this user made in the
--    prior 12h, and how much have they sent? (window function version —
--    faster than a correlated subquery for whole-table feature building.)
SELECT
    transaction_id, user_id, created_ts, send_amount,
    count(*) OVER (
        PARTITION BY user_id ORDER BY created_epoch
        RANGE BETWEEN 43200 PRECEDING AND 1 PRECEDING
    ) AS txns_prior_12h,
    sum(send_amount) OVER (
        PARTITION BY user_id ORDER BY created_epoch
        RANGE BETWEEN 43200 PRECEDING AND 1 PRECEDING
    ) AS amount_sent_prior_12h
FROM transactions
ORDER BY txns_prior_12h DESC, created_epoch
LIMIT 10;

--  transaction_id | user_id |     created_ts      | send_amount | txns_prior_12h | amount_sent_prior_12h 
-- ----------------+---------+---------------------+-------------+----------------+-----------------------
--  T0017742       | U00639  | 2026-01-22 14:14:41 |        2.14 |             10 |    52.720000000000006
--  T0017710       | U00617  | 2026-01-23 08:13:21 |        5.39 |             10 |                 51.82
--  T0003190       | U00151  | 2026-03-20 19:04:20 |      238.45 |             10 |                 46.14
--  T0017741       | U00639  | 2026-01-22 14:12:41 |        2.78 |              9 |    49.940000000000005
--  T0017709       | U00617  | 2026-01-23 08:11:21 |        5.65 |              9 |                 46.17
--  T0017684       | U00151  | 2026-03-20 13:41:09 |        2.13 |              9 |                 44.01
--  T0017796       | U00469  | 2026-04-25 00:09:42 |        1.18 |              9 |                 40.11
--  T0017740       | U00639  | 2026-01-22 14:10:41 |        7.88 |              8 |                 42.06
--  T0017708       | U00617  | 2026-01-23 08:09:21 |        6.67 |              8 |                  39.5
--  T0017718       | U00156  | 2026-01-26 16:39:14 |        1.54 |              8 |                260.75
-- (10 rows)

-- 5. Failed login count for the user in the 12h before the transaction —
--    another common fraud signal (credential stuffing before a payout).
SELECT
    t.transaction_id, t.user_id, t.created_ts, send_amount,
    (SELECT count(*) FROM login_events le
     WHERE le.user_id = t.user_id
       AND le.login_success = 0
       AND le.login_epoch BETWEEN t.created_epoch - 43200 AND t.created_epoch - 1
    ) AS failed_logins_prior_12h
FROM transactions t
ORDER BY failed_logins_prior_12h DESC, t.send_amount DESC, t.created_epoch
LIMIT 10;

--  transaction_id | user_id |     created_ts      | send_amount | failed_logins_prior_12h 
-- ----------------+---------+---------------------+-------------+-------------------------
--  T0017550       | U00789  | 2026-04-26 20:32:05 |     3085.13 |                       4
--  T0017571       | U00278  | 2026-05-05 10:10:35 |      2856.1 |                       4
--  T0017529       | U00095  | 2026-03-27 20:32:18 |     2644.19 |                       4
--  T0017581       | U00740  | 2026-06-10 16:44:23 |     2488.16 |                       4
--  T0017570       | U00278  | 2026-05-05 09:58:35 |     2446.61 |                       4
--  T0017528       | U00095  | 2026-03-27 20:20:18 |     2351.31 |                       4
--  T0017580       | U00740  | 2026-06-10 16:32:23 |     2030.41 |                       4
--  T0017572       | U00776  | 2026-06-07 17:07:13 |     1893.85 |                       4
--  T0017573       | U00776  | 2026-06-07 17:19:13 |     1890.28 |                       4
--  T0017549       | U00789  | 2026-04-26 20:20:05 |     1759.84 |                       4

-- check amount sent in a transaction using transaction_id
SELECT send_amount FROM transactions WHERE transaction_id = 'T0017549'


-- To run non-interactively, use psql with the -f flag:
--   psql -h localhost -p 5433 -U fraud -d fraud -f sql/explore_joins.sql