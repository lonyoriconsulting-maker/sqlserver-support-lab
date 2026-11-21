# sqlserver-support-lab

A portfolio project showing hands-on SQL Server 2022 administration and support skills. Everything here runs on a local SQL Server 2022 Developer instance, using **fictional practice data only**.

## Who this is for

Anyone reviewing my database support skills: first-line and second-line application support, business systems administration, and SQL Server support work. Each section below says what I built, where the proof is, and what is still in progress.

## Honest background

My production database experience is PostgreSQL on client systems (Django/DRF applications). This lab shows how I apply that experience to SQL Server 2022. It is a practice environment, not a production deployment, and the status table below shows exactly what is done and what is not.

## Everything this lab covers

### 1. Environment and tooling
- SQL Server 2022 Developer Edition installed and verified (services, version, file paths)
- Default backup location configured on a separate drive
- Connecting with `sqlcmd` and the VS Code MSSQL extension
- Git and GitHub workflow for every script (small commits, `.gitignore` for backups and data files)

### 2. Real schema port: SQLite to SQL Server
- Application: a Django/DRF fleet telematics system (drivers, vehicles, trips, telemetry, violations such as fuel siphoning)
- Type mapping, primary and foreign keys, check constraints, indexes, a reserved-word column rename
- Fictional sample data to exercise the queries

### 3. DBA and support queries (10)
Health check, file sizes and locations, row counts, last backup audit, sessions and blocking, fuel-siphoning detection with window functions, overspeed incident lookup, trip summaries, violations report, index inventory.

### 4. SQL Server practice lessons (12)
Numbered files in `lessons/`:

1. Orientation: system databases, `INFORMATION_SCHEMA`
2. `SELECT`, `WHERE`, `LIKE`, `NULL`, and T-SQL differences from PostgreSQL
3. Joins: inner, left, finding orphan rows
4. `GROUP BY`, `HAVING`, date functions, `CASE`
5. Building a practice database with keys and constraints
6. Transactions, `ROLLBACK`, `TRY/CATCH`
7. Views and stored procedures
8. Indexes and execution plans on 100,000 fictional rows
9. Backup and recovery: full, differential and log backups, restore to a test copy, RPO and RTO, the 3-2-1 rule
10. Security and access: logins, users, roles, `GRANT` and `DENY`, access review query, leaver process, segregation of duties
11. Monitoring and troubleshooting: DMVs, a blocking exercise, error log, disk space
12. Change management capstone: a change pack with deploy, verify and rollback scripts

### 5. Backup and recovery
- Backup script (full, differential, log) with `CHECKSUM`
- Restore procedure with screenshots, tested by restoring to a separate copy
- Restore SOP in `sops/`

### 6. Access management
- Logins, database users and roles script following least privilege
- Access review query and SOP
- Leaver (account deactivation) procedure

### 7. Change management
- Controlled deployment pattern: test in a non-production copy, deploy, verify, roll back if needed
- Reusable change request and rollback templates

## Repository layout

```
scripts/       numbered, re-runnable SQL scripts
lessons/       numbered practice lessons
sops/          standard operating procedures (restore, access review, change)
screenshots/   proof that each step ran (fictional data only)
```

## Status

| Item | Status |
|---|---|
| SQL Server 2022 verified, test backup works | Done (21 Nov 2026) |
| Telematics schema ported from SQLite | Done (21 Nov 2026) |
| 10 DBA queries with output proof | Done (21 Nov 2026) |
| Lessons 1 to 4: querying fundamentals | Not started |
| Lessons 5 to 8: building, transactions, programmability, indexing | Not started |
| Lesson 9 plus backup script and restore SOP | Not started |
| Lesson 10 plus logins and roles script, access review SOP | Not started |
| Lesson 11: monitoring and troubleshooting | Not started |
| Lesson 12: change management pack | Not started |

## Rules for this repo

- Fictional data only
- No passwords, no real company or client data
- No `.bak`, `.mdf`, `.ldf` files committed
- Every script is re-runnable and commented with what it is used for
