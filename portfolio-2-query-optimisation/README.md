# Portfolio 2: Query Processing and Optimisation

## 1. Project Overview

This portfolio explores query processing and optimisation using the simulated SwiftPay fintech PostgreSQL database developed in Portfolio 1.

The aim is to examine how PostgreSQL executes common database queries, interpret execution plans, and evaluate whether additional indexes can improve query performance.

## 2. Database Environment

- **Database system:** PostgreSQL
- **Database client:** DBeaver
- **Database schema:** `quickpay`
- **Dataset:** Simulated SwiftPay fintech data
- **Analysis tool:** `EXPLAIN (ANALYZE, BUFFERS)`

## 3. Project Files

| File or folder            | Purpose                                                                    |
| ------------------------- | -------------------------------------------------------------------------- |
| `queries.sql`             | Contains the four SQL queries evaluated in this portfolio.                 |
| `indexes.sql`             | Contains the candidate index created to test query optimisation.           |
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

## 7. Conclusion

This portfolio demonstrates how PostgreSQL execution plans can be used to investigate query behaviour and evaluate potential indexes.

The results highlight that indexes should be selected based on query requirements and verified through testing. For small tables, sequential scans can be more appropriate than index scans. Further testing with a larger, representative dataset would be required to assess the practical benefit of the candidate index.
