# Portfolio 4: NoSQL and Advanced Data Models

## Case Study

This portfolio extends the simulated **QuickPay** fintech platform from Portfolios 1–3. PostgreSQL remains the source of truth for accounts, transfers, and the ledger; **MongoDB Atlas** is used for workloads that suit non-relational models, implementing **three NoSQL data models**:

| Model     | Collection              | Use in QuickPay                                                  |
| --------- | ----------------------- | ---------------------------------------------------------------- |
| Document  | `transaction_events`    | Transfer event log with polymorphic, nested metadata             |
| Key-value | `account_balance_cache` | Balance lookups by account number, auto-expiring (TTL)           |
| Graph     | `transfer_edges`        | Money-flow tracing / circular-flow detection with `$graphLookup` |

## Objectives

- Design a document model with embedding and polymorphic fields.
- Enforce data quality with `$jsonSchema` validation.
- Demonstrate index optimisation using `explain()` before and after.
- Analyse data with aggregation pipelines.
- Implement key-value and graph models on the same case study.
- Evaluate MongoDB's suitability compared with PostgreSQL.

## Technologies

MongoDB Atlas · Node.js · MongoDB Node.js driver · dotenv · TablePlus

## Project Files

| File                          | Purpose                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `transaction-events.json`     | Original 3 sample event documents (imported into Atlas).                                                              |
| `collections.js`              | Stage 1: basic queries and a status aggregation on the sample documents.                                              |
| `advanced.js`                 | Stage 2: timestamp fix, 2,000 generated events, validation, indexing, aggregations, key-value cache, graph traversal. |
| `nosql-analysis.md`           | Full design rationale, results, comparison with PostgreSQL, and limitations.                                          |
| `results/advanced-output.txt` | Captured console output of `advanced.js`.                                                                             |
| `screenshots/`                | Evidence from the terminal and Atlas/TablePlus.                                                                       |
| `package.json`                | Dependencies and run scripts.                                                                                         |
| `.env` (not committed)        | `MONGODB_URI` connection string.                                                                                      |

## Setup and Execution

1. `npm install`
2. Create `.env` containing `MONGODB_URI="your-atlas-connection-string"`.
3. Ensure Atlas network access allows your IP and the user has read/write access to `quickpay_nosql`.
4. Import `transaction-events.json` into `quickpay_nosql.transaction_events` (first time only).
5. Run:
   - `npm run basic`: Stage 1 queries
   - `npm run advanced`: Stage 2 (re-runnable; it replaces only the generated `GEN-` events)

## Key Results

| Test                             | Result                                                                                                              |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Timestamp normalisation          | 3 string timestamps converted to BSON `Date`                                                                        |
| Data volume                      | 2,003 events (3 original + 2,000 generated)                                                                         |
| Schema validation                | Invalid document (negative amount, bad currency, bad status) **rejected, code 121**                                 |
| Index `{status:1, timestamp:-1}` | `COLLSCAN + SORT` examining **2,003** docs became `IXSCAN` examining **20** docs, with no in-memory sort            |
| Aggregations                     | Channel success rates (about 80%); top failure reason `suspected_fraud` (46); monthly volume; iOS 260 / Android 237 |
| Key-value lookup                 | `EXPRESS_IXSCAN(_id_)`: 1 key, 1 doc, 0 ms; balance ₦149,000 matches PostgreSQL                                     |
| Graph traversal                  | 90 edges; account 1 reaches all accounts in 1 hop; **circular flow back to account 1 in 2 hops**                    |
| Data-quality finding             | 1 failed event with `null` failure reason caused by schema drift in the original sample (explained in analysis)     |

## Evidence

| Screenshot                              | Shows                                                                             |
| --------------------------------------- | --------------------------------------------------------------------------------- |
| `01-mongo-db-query-results.png`         | Stage 1 query output                                                              |
| `02-transaction-events-collection.png`  | Imported sample documents                                                         |
| `03-mongodb-database-structure.png`     | Database and collection structure                                                 |
| `04-timestamps-and-validations.png`     | Timestamp conversion, 2,000 events inserted, invalid document rejected (code 121) |
| `05-index-before-after.png`             | `explain()` before (COLLSCAN, 2,003 docs) and after (IXSCAN, 20 docs); index list |
| `06-aggregations-channels-failures.png` | Channel success rates and failure reasons                                         |
| `07-aggregations-monthly-device.png`    | Monthly completed volume and device OS breakdown                                  |
| `08-key-value-cache.png`                | Balance cache lookup via `EXPRESS_IXSCAN(_id_)`                                   |
| `09-graph-lookup.png`                   | `$graphLookup` reachability and circular-flow detection                           |
| `10-collections.png`                    | The three collections in `quickpay_nosql`                                         |
| `11-Indexes.png`                        | Indexes on `transaction_events` in Atlas                                          |

## Suitability Summary

MongoDB suits QuickPay's **event history** (variable structure, append-only, analytical queries), **caching** (fast key lookups with automatic expiry), and **relationship tracing** (graph traversal for fraud). PostgreSQL remains appropriate for **balances and the ledger**, which require multi-row ACID transactions, foreign keys, and row locking (Portfolio 3). The recommended architecture is **polyglot persistence**, with events published from PostgreSQL after commit.

See `nosql-analysis.md` for the full analysis.

## Limitations

Synthetic data (10 accounts, uniform probabilities, fully connected transfer graph); small collection sizes; synchronisation between PostgreSQL and MongoDB is designed but not implemented. The connection string is kept in `.env` and excluded from Git.
