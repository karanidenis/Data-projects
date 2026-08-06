-- Raw operational tables. Portable across PostgreSQL and SQLite.
-- Timestamps stored as ISO text plus precomputed epoch seconds (created by ETL)
-- so window/interval math is identical on both engines.

DROP TABLE IF EXISTS users;
CREATE TABLE users (
    user_id            TEXT PRIMARY KEY,
    signup_ts          TEXT,
    signup_epoch       BIGINT,
    residence_country  TEXT,
    birth_year         INTEGER,
    kyc_level          TEXT,
    kyc_verified_ts    TEXT,
    signup_channel     TEXT,
    phone_country      TEXT
);

DROP TABLE IF EXISTS recipients;
CREATE TABLE recipients (
    recipient_id     TEXT PRIMARY KEY,
    created_ts       TEXT,
    created_epoch    BIGINT,
    receive_country  TEXT,
    payout_method    TEXT,
    account_masked   TEXT
);

DROP TABLE IF EXISTS login_events;
CREATE TABLE login_events (
    user_id        TEXT,
    login_ts       TEXT,
    login_epoch    BIGINT,
    device_id      TEXT,
    ip_address     TEXT,
    ip_country     TEXT,
    os             TEXT,
    login_success  INTEGER,
    auth_method    TEXT
);

DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
    transaction_id  TEXT PRIMARY KEY,
    user_id         TEXT,
    recipient_id    TEXT,
    created_ts      TEXT,
    created_epoch   BIGINT,
    created_date    TEXT,
    created_hour    INTEGER,
    send_amount     DOUBLE PRECISION,
    send_currency   TEXT,
    receive_amount  DOUBLE PRECISION,
    receive_currency TEXT,
    fx_rate         DOUBLE PRECISION,
    fee_amount      DOUBLE PRECISION,
    payment_method  TEXT,
    payout_method   TEXT,
    device_id       TEXT,
    ip_address      TEXT,
    ip_country      TEXT,
    status          TEXT,
    decline_reason  TEXT
);


CREATE INDEX idx_txn_user_epoch   ON transactions (user_id, created_epoch);
CREATE INDEX idx_txn_recip_epoch  ON transactions (recipient_id, created_epoch);
CREATE INDEX idx_login_user_epoch ON login_events (user_id, login_epoch);
