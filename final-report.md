# MIT 8103 Advanced Database Systems: Portfolio Final Report

**Student:** Aladi Adaorah · **Matric No.:** 2026/A/MIT/0591301923627 · **Session:** 2026/2027, First Semester
**GitHub repository:** https://github.com/debbydora/mit-8103-advanced-database-portfolio
**Case study:** QuickPay, a simulated fintech payments platform

## 1. Selected Organisation

QuickPay is a simulated Nigerian digital payments platform where customers hold NGN accounts and transfer funds via mobile, web, USSD, and API channels. Database users include customers (through apps), the payments service, support, finance, fraud/compliance staff, and DBAs. Core data comprises customers, accounts, transfers, a double-entry ledger, and audit logs (PostgreSQL), plus transaction events, a balance cache, and a money-flow graph (MongoDB). Key operations are atomic transfers, statements, reporting, auditing, and fraud tracing. Full details: `docs/case-study.md`.

## 2. Portfolio 1: Database Design and Modelling

A normalised (3NF) PostgreSQL schema of five tables was designed in a dedicated `quickpay` schema and documented with a Mermaid ER diagram. Integrity is enforced through identity primary keys, foreign keys with `ON DELETE RESTRICT`, case-insensitive unique emails, and CHECK constraints (non-negative balances, ISO currency codes, status enums, source ≠ destination, completed transfers must have `completed_at`). Ledger entries are unique per transfer, account, and entry type, supporting double-entry bookkeeping. Money uses `NUMERIC(19,4)` to avoid floating-point error. Seed data and verification queries confirmed relationships and constraints.
_Evidence:_ `portfolio-1-database-design/` (schema, seed, queries, ER diagram, 10 screenshots).

## 3. Portfolio 2: Query Processing and Optimisation

Four business queries were analysed with `EXPLAIN (ANALYZE, BUFFERS)`. On the 10-row seed data, sequential scans were correct and no index helped, so 200,000 synthetic transfers were generated and each candidate index was tested before and after:

| Test                                        | Before                                  | After                                      |
| ------------------------------------------- | --------------------------------------- | ------------------------------------------ |
| Recent successful transfers (partial index) | Parallel Seq Scan + Sort, 960.683 ms    | Index Scan, no sort, **0.082 ms**          |
| Account statement (composite index)         | Bitmap Scan + Sort, 124.437 ms          | Index Scan, no sort, **0.103 ms**          |
| 30-day volume (`created_at` index)          | Skip scan on existing index, 206.742 ms | New index **never used**: recommended drop |

Index sizes and usage from `pg_stat_user_indexes` informed keep/drop decisions, weighing read gains against storage and write overhead.
_Evidence:_ `portfolio-2-query-optimisation/` (scripts, 13 execution-plan screenshots, analysis).

## 4. Portfolio 3: Transactions and Concurrency

Twelve exercises using two DBeaver sessions demonstrated:

- **Atomicity:** a ₦1,000 transfer committing five writes together (balances ₦150,000/₦275,000 → ₦149,000/₦276,000, balanced ledger).
- **Automatic rollback:** an insufficient-funds transfer wrote nothing.
- **Isolation:** no dirty reads under `READ COMMITTED`.
- **Lost update anomaly:** the balance ended at ₦148,800 instead of ₦148,700.
- **Prevention with `SELECT … FOR UPDATE`:** the correct ₦148,700.
- **Deadlock detection:** Session B was aborted.
- **Serialization failure under `REPEATABLE READ`.**

The recommended transfer design locks accounts in ascending ID order and retries on conflict.
_Evidence:_ `portfolio-3-transactions-concurrency/` (2 SQL scripts, 20 screenshots).

## 5. Portfolio 4: NoSQL and Advanced Data Models

MongoDB Atlas implemented three models for the same case study:

- **Document:** 2,003 polymorphic transaction events.
- **Key-value:** a TTL balance cache with a single-key lookup.
- **Graph:** `$graphLookup` money-flow tracing that detected a 2-hop circular flow.

A `$jsonSchema` validator rejected an invalid event (code 121). A compound index reduced documents examined from 2,003 to 20 and removed the in-memory sort. Aggregations reported channel success rates, failure reasons, and monthly volume. A schema-drift defect (one event with a null failure reason) illustrated the risks of flexible schemas. A polyglot-persistence architecture is recommended, with PostgreSQL as the source of truth.
_Evidence:_ `portfolio-4-nosql/` (Node.js scripts, output log, 11 screenshots).

## 6. Portfolio 5: Distributed and Cloud Database

The database is deployed on **Render** (managed PostgreSQL), verified with connectivity, schema, and record-count tests. Replication, availability, consistency (including replica lag), and sharding trade-offs were analysed, and a cloud architecture was proposed. Practically:

- **Range partitioning** by month routed 200,011 rows into monthly partitions. **Partition pruning** cut an August query from 934.662 ms / 17,092 pages to **7.880 ms / 291 pages**.
- `DETACH PARTITION` archived 4,198 rows instantly.
- **Hash partitioning** simulated 4 shards. Queries with the shard key touched 1 shard (82.789 ms), while queries without it scattered to all 4 (327.395 ms). A **hot shard** (40% of rows) revealed the skew risk of a low-cardinality key.

_Evidence:_ `portfolio-5-distributed-cloud/` (SQL, analyses, results log, 13 screenshots).

## 7. Summary

Across the five portfolios, the same QuickPay case study was carried from design through optimisation, transaction safety, NoSQL modelling, and distribution. Every claim is supported by scripts and measured evidence in the repository. Individual reflection, references, and the AI-use declaration are in `docs/technical-reflection.md`.
