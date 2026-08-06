"""ETL: raw CSVs -> database tables (schema in sql/01_schema.sql).

Adds derived-at-load columns (epoch seconds, date, hour, ip_country) so all
downstream SQL is engine-portable. Run:  python src/load_data.py
"""
import pandas as pd
from pathlib import Path
from db import connect, run_sql_file, ROOT

DATA = ROOT / "data"
SQL = ROOT / "sql"


def epoch(s):
    # resolution-independent (pandas may parse as ns/us/s depending on version)
    return (pd.to_datetime(s) - pd.Timestamp("1970-01-01")) // pd.Timedelta("1s")


def ip_country(s):
    return s.str.split(".").str[0]


def insert(conn, ph, table, df):
    cols = ",".join(df.columns)
    marks = ",".join([ph] * len(df.columns))
    cur = conn.cursor()
    cur.executemany(
        f"INSERT INTO {table} ({cols}) VALUES ({marks})",
        df.where(pd.notna(df), None).values.tolist(),
    )
    conn.commit()
    cur.close()
    print(f"  {table}: {len(df)} rows")


def main():
    conn, ph, backend = connect()
    print(f"Backend: {backend}")
    run_sql_file(conn, backend, SQL / "schema.sql")

    u = pd.read_csv(DATA / "users.csv")
    u["signup_epoch"] = epoch(u.signup_ts)
    insert(conn, ph, "users", u[["user_id", "signup_ts", "signup_epoch",
        "residence_country", "birth_year", "kyc_level", "kyc_verified_ts",
        "signup_channel", "phone_country"]])

    r = pd.read_csv(DATA / "recipients.csv")
    r["created_epoch"] = epoch(r.created_ts)
    insert(conn, ph, "recipients", r[["recipient_id", "created_ts",
        "created_epoch", "receive_country", "payout_method", "account_masked"]])

    le = pd.read_csv(DATA / "login_events.csv")
    le["login_epoch"] = epoch(le.login_ts)
    le["ip_country"] = ip_country(le.ip_address)
    insert(conn, ph, "login_events", le[["user_id", "login_ts", "login_epoch",
        "device_id", "ip_address", "ip_country", "os", "login_success",
        "auth_method"]])

    t = pd.read_csv(DATA / "transactions.csv")
    ts = pd.to_datetime(t.created_ts)
    t["created_epoch"] = epoch(t.created_ts)
    t["created_date"] = ts.dt.date.astype(str)
    t["created_hour"] = ts.dt.hour
    t["ip_country"] = ip_country(t.ip_address)
    insert(conn, ph, "transactions", t[["transaction_id", "user_id",
        "recipient_id", "created_ts", "created_epoch", "created_date",
        "created_hour", "send_amount", "send_currency", "receive_amount",
        "receive_currency", "fx_rate", "fee_amount", "payment_method",
        "payout_method", "device_id", "ip_address", "ip_country", "status",
        "decline_reason"]])

    print("Loaded.")
    conn.close()


if __name__ == "__main__":
    main()
