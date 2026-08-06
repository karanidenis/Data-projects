"""Database adapter.

Set DATABASE_URL=postgresql://user:pass@host:5432/fraud to use PostgreSQL
(requires psycopg2-binary). Without it, falls back to a local SQLite file so
the whole pipeline runs anywhere with zero setup.
"""
import os
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQLITE_PATH = ROOT / "data" / "fraud.db"
DATABASE_URL = 'postgresql://fraud:fraud@localhost:5433/fraud'
# DATABASE_URL = os.getenv("DATABASE_URL", "")


def connect():
    if DATABASE_URL.startswith("postgres"):
        import psycopg2
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = True
        return conn, "%s", "postgres"
    conn = sqlite3.connect(SQLITE_PATH)
    return conn, "?", "sqlite"


def run_sql_file(conn, backend, path):
    sql = Path(path).read_text()
    cur = conn.cursor()
    if backend == "postgres":
        cur.execute(sql)
    else:
        # sqlite: strip DOUBLE PRECISION -> REAL is unnecessary (sqlite accepts any
        # type name), but executescript is needed for multi-statement files.
        conn.executescript(sql)
    conn.commit() if backend == "sqlite" else None
    cur.close()


def read_df(conn, query):
    import pandas as pd
    return pd.read_sql_query(query, conn)
