# Portfolio 2: Query Processing and Optimisation

## 1. Project Overview

This portfolio explores query processing and optimisation using the simulated Quickpay fintech PostgreSQL database developed in Portfolio 1.

The aim is to examine how PostgreSQL executes common database queries, interpret execution plans, and evaluate whether additional indexes can improve query performance.

## 2. Database Environment

- **Database system:** PostgreSQL
- **Database client:** DBeaver
- **Database schema:** `quickpay`
- **Dataset:** Simulated Quickpay fintech data
- **Analysis tool:** `EXPLAIN (ANALYZE, BUFFERS)`

## 3. Project Files

| File or folder            | Purpose                                                                    |
| ------------------------- | -------------------------------------------------------------------------- |
| `queries.sql`             | Contains the four SQL queries evaluated in this portfolio.                 |
| `indexes.sql`             | Contains the candidate indexes created to test query optimisation.         |
| `bulk-data.sql`           | Generates 200,000 synthetic transfers for realistic-volume testing.        |
| `optimisation-tests.sql`  | Before/after `EXPLAIN (ANALYZE, BUFFERS)` tests for each candidate index.  |
| `performance-analysis.md` | Documents baseline execution plans, observations, and index-test findings. |
| `execution-plans/`        | Stores screenshots of the baseline and post-index execution plans.         |
| `screenshots/`            | Stores other supporting screenshots, if applicable.                        |

## 4. Queries Analysed

Four queries were evaluated:

1. **Customer account lookup:** Joins customers and accounts to retrieve account information for a customer.
2. **Recent successful transfers:** Retrieves successful transfers with completion timestamps, ordered by completion time.
3. **Daily transfer volume:** Groups transfers by date and currency, calculating the transfer count and total amount.
4. **Failed transfers:** Retrieves failed transfers, ordered by creation time.

## 5. Query Execution Analysis

PostgreSQL execution plans were obtained using `EXPLAIN (ANALYZE, BUFFERS)`. The analysis considered scan methods, index usage, join methods, sorting, aggregation, buffer activity, planning time, and execution time.

The baseline plans showed that existing indexes supported the customer account lookup and transfer status filters. The daily transfer volume query used a sequential scan, which was reasonable for the small dataset.

## 6. Index Optimisation Experiment

A partial index named `idx_transfers_successful_completed_at` was created on `quickpay.transfers` using `completed_at DESC`, restricted to successful transfers with non-null completion timestamps.

The original successful-transfer query took **0.069 ms**, while the post-index execution took **0.054 ms**. Both executions returned five rows.

However, PostgreSQL chose a sequential scan and retained a separate sort operation in the post-index plan. The small dataset and variation in execution timings mean the observed difference does not establish that the new index improved performance.

## 7. Scaled Optimisation Experiment (200,000 transfers)

Because the 10-row seed dataset was too small to show index benefits, `bulk-data.sql` was used to generate 200,000 synthetic transfers (85% successful, 8% failed, the rest pending/processing/reversed) spread over 365 days. `optimisation-tests.sql` was then run, capturing each plan before and after creating the candidate index.

| Test | Query                                | Candidate index                                   | Before (plan / time)                                            | After (plan / time)                        |
| ---- | ------------------------------------ | ------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------ |
| A    | Recent successful transfers          | `idx_transfers_successful_completed_at` (partial) | Parallel Seq Scan + Sort / 960.683 ms                           | Index Scan, no Sort / 0.082 ms             |
| B    | Account statement (last 20 outgoing) | `idx_transfers_source_created` (composite)        | Bitmap Heap Scan + Sort / 124.437 ms                            | Index Scan, no Sort / 0.103 ms             |
| C    | Daily volume, last 30 days           | `idx_transfers_created_at`                        | Skip scan on `idx_transfers_status_created` + Sort / 206.742 ms | Same plan, new index not used / 187.891 ms |
| D    | Failed transfers (control)           | existing `idx_transfers_status_created`           | Index Scan, no Sort / 0.126 ms                                  | n/a                                        |

**Findings:** The partial index (A) and the composite index (B) removed the full scan and the sort, cutting page reads from about 3,470 to 23. The created-at index (C) was never chosen by the planner (0 scans in `pg_stat_user_indexes`), so it is recommended for removal. The full analysis is in `performance-analysis.md`.

Execution-plan screenshots are stored in `execution-plans/` as `test-a-before.png`, `test-a-after.png`, and so on. Index sizes are recorded from `pg_stat_user_indexes` to weigh the read benefit against storage and write overhead.

## 8. Conclusion

This portfolio demonstrates how PostgreSQL execution plans can be used to investigate query behaviour and evaluate potential indexes.

The results highlight that indexes should be selected based on query requirements and verified through testing. On the 10-row seed data, sequential scans were the correct planner choice. On the 200,000-row dataset, well-designed indexes cut execution time from 960 ms to 0.08 ms, while a plausible but unsuitable index went unused, showing that execution plans, not assumptions, should decide which indexes to keep.
