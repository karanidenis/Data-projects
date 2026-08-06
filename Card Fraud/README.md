# Cross-Border Payments Fraud Detection

End-to-end fraud detection for a remittance company: raw operational
data → PostgreSQL → SQL feature engineering → ML models → alert queue.

## Architecture

```
CSVs (raw ops data)          sql/schema.sql   (DDL + indexes)
  users, recipients,   -->   src/load_data.py    (ETL: epochs, ip_country)
  login_events,
  transactions
```

## Run with PostgreSQL

```bash
docker compose up -d
pip install -r requirements.txt
export DATABASE_URL=postgresql://fraud:fraud@localhost:5433/fraud
python src/load_data.py
```
For local dev, you can also run the SQL directly in psql:

```bash
psql -h localhost -p 5433 -U fraud -d fraud -f sql/schema.sql
psql -h localhost -p 5433 -U fraud -d fraud -f sql/explore_joins.sql
psql -h localhost -p 5433 -U fraud -d fraud -f sql/validate.sql
``` 

## Run with zero setup (SQLite fallback)

Same commands, just skip docker and the export. Identical SQL runs on both.

## Feature groups (all computed in SQL, point-in-time correct)

- Amount/behavior: amount vs user's prior average, velocity 1h/12h, sums
- Device/login: new device flag, failed logins in prior hour, seconds since
  last successful login, IP-country vs residence mismatch
- Recipient: account age, transactions from all senders in 30d, distinct
  senders to date (mule detection)
- Context: hour, night flag, near-reporting-threshold amounts, failed status

## Labels

TBC

## Evaluation

TBC
