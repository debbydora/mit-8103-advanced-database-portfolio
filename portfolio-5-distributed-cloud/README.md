# Portfolio 5: Distributed and Cloud Database Exercise

## Case Study

This portfolio extends the simulated QuickPay fintech platform developed in the earlier portfolio activities. QuickPay manages customers, accounts, transfers, ledger entries, and audit logs.

## Objectives

- Examine cloud database deployment.
- Verify connectivity to a hosted PostgreSQL database.
- Analyse replication, sharding, availability, and consistency.
- Propose improvements for scaling and database resilience.
- Document implementation evidence and testing results.

## Technologies Used

- PostgreSQL
- Render PostgreSQL hosting
- DBeaver
- SQL

## Project Structure

| File or folder                  | Purpose                                                                                   |
| ------------------------------- | ----------------------------------------------------------------------------------------- |
| `README.md`                     | Portfolio overview and instructions                                                       |
| `deployment-test.sql`           | Read-only checks for database connectivity, schema, version, timestamp, and record counts |
| `cloud-architecture.md`         | Proposed cloud architecture and component responsibilities                                |
| `distributed-cloud-analysis.md` | Analysis of replication, sharding, availability, and consistency                          |
| `partitioning.sql`              | Practical range partitioning (by month) and hash partitioning (sharding simulation)       |
| `partitioning-analysis.md`      | Results and analysis of the partitioning and sharding demonstration                       |
| `results/`                      | Captured query outputs and execution plans                                                |
| `screenshots/`                  | Evidence captured during cloud database verification and partitioning tests               |

## Implementation

The existing QuickPay PostgreSQL database is hosted on Render. DBeaver was used to connect to the database and execute read-only verification queries.

The tests examine the connected database and PostgreSQL version, the active schema, the five expected QuickPay tables, record counts, and session information.

## How to Run the Tests

1. Ensure that the Render PostgreSQL database is available and that you have valid connection credentials.
2. Open the database connection in DBeaver.
3. Open `deployment-test.sql`.
4. Execute the queries against the intended QuickPay database.
5. Verify the query results and compare the table names with the expected schema.
6. Review the screenshots in `screenshots/`.

Do not place passwords or private connection strings in this repository. Keep credentials in a secure location.

## Evidence

The `screenshots/` folder contains evidence of the cloud connection, database details, schema verification, and record counts.

These screenshots demonstrate database accessibility at the time of testing. They do not independently prove that replication, sharding, or automatic failover is configured.

## Distributed Database Analysis

`distributed-cloud-analysis.md` explains the benefits and trade-offs of replication, sharding, availability, and consistency for QuickPay.

`cloud-architecture.md` proposes an architecture that includes a primary database, a potential read replica, backups, monitoring, and recovery procedures.

Replication and automatic failover are proposed enhancements. Data distribution was demonstrated practically, as described below.

## Practical Partitioning and Sharding Demonstration

`partitioning.sql` was run against the Render database using the 200,011 transfers from Portfolio 2 (copies only; the live table was not changed). Full analysis: `partitioning-analysis.md`.

| Test                                            | Result                                                                                                                               |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Range partitioning by month                     | 200,011 rows routed automatically into 13 monthly partitions (about 16–17k rows per full month)                                      |
| Partition pruning (August query)                | Unpartitioned: 934.662 ms, 17,092 pages. Partitioned: **7.880 ms, 291 pages**, scanning only `transfers_2026_08` (about 119× faster) |
| Data retention (`DETACH PARTITION`)             | 200,011 → 195,813 rows; 4,198 October 2025 rows archived instantly as a separate table                                               |
| Hash sharding (4 shards by `source_account_id`) | Each account on exactly one shard; shard_1 held 40% (accounts 3 and 5), a **hot shard** caused by few keys                           |
| Query with shard key                            | Routed to **1 shard**: 82.789 ms, 820 pages                                                                                          |
| Query without shard key                         | **Scatter-gather across all 4 shards**: 327.395 ms, 2,052 pages                                                                      |

| Screenshot                                                     | Shows                                              |
| -------------------------------------------------------------- | -------------------------------------------------- |
| `05-range-partition-distribution.png`                          | Rows per monthly partition                         |
| `06a-pruning-unpartitioned.png`, `06b-pruning-partitioned.png` | Execution plans before/after partitioning          |
| `07-1-detach-partition.png`, `07-2-detach-partition.png`       | Row counts before/after detaching the oldest month |
| `08-shard-distribution.png`                                    | Rows and accounts per hash shard                   |
| `09a-single-shard-query.png`, `09b-all-shards-query.png`       | Shard routing vs scatter-gather plans              |

## Limitations

This activity verifies access to a cloud-hosted PostgreSQL database, and demonstrates range partitioning and shard placement and routing on a single instance. It does not implement a multi-node replicated or sharded cluster; network latency, node failure, failover, and rebalancing were not tested.

## Conclusion

The portfolio demonstrates cloud database accessibility and shows, with measured results, how partitioning reduces work through pruning and simplifies retention, and how a shard key determines whether a query touches one shard or all of them. The design prioritises financial data integrity, recommending monthly range partitioning first and account-based sharding only when a single instance can no longer scale, given the distributed-transaction costs for cross-shard transfers.
