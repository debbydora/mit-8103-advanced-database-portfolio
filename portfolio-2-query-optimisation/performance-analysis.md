## Query 1: Customer Accounts Lookup

**Purpose:** Retrieve a customer's details alongside their associated account information.

**Baseline execution plan findings**

- **Customer lookup:** PostgreSQL used the primary-key index `customers_pkey` to find customer ID 5.
- **Account lookup:** PostgreSQL used `idx_accounts_customer_id` to find accounts belonging to customer ID 5.
- **Join method:** A nested-loop join combined the customer and account records.
- **Sorting:** PostgreSQL used quicksort to order the results by `account_id`.
- **Rows returned:** 1 row.
- **Execution time:** 0.079 ms.
- **Planning time:** 0.140 ms.
- **Buffer activity:** 4 shared-buffer hits were reported.

**Analysis:** The query benefits from existing indexes on `customers.customer_id` and `accounts.customer_id`. The execution plan indicates that PostgreSQL efficiently located the matching customer and account. Since the dataset is small and the query completed in 0.079 ms, additional indexes should not be recommended without further testing. The baseline will be used for comparison with any subsequent optimisation.

**Conclusion:** The query executes successfully using the existing primary-key and customer foreign-key indexes. Its performance should be compared against plans obtained after any justified index changes.

## Query 2: Recent Successful Transfers

**Purpose:** Retrieve successful transfers with a completion timestamp, showing the most recent transfers first, up to a maximum of 20 records.

**Baseline execution plan findings**

- **Index used:** `idx_transfers_status_created`.
- **Index condition:** The transfer status must be `successful`.
- **Filter:** Rows with a `NULL` `completed_at` value are excluded.
- **Sorting:** PostgreSQL used quicksort to order results by `completed_at` in descending order.
- **Rows returned:** 5 rows.
- **Execution time:** 0.069 ms.
- **Planning time:** 0.361 ms.
- **Buffer activity:** 5 shared-buffer hits were reported in the plan's execution nodes.

**Analysis:** PostgreSQL used the existing index to locate successful transfers, but the index is based on transfer status and creation time rather than completion time. Therefore, the plan still includes a separate sort on `completed_at`. With only five rows returned and an execution time of 0.069 ms, the sort is inexpensive for the current dataset.

**Potential optimisation:** A composite or partial index involving `completed_at` may help if the database grows substantially and this query is frequently executed. Any proposed index should be tested against the baseline, as additional indexes consume storage and add overhead to data modifications.

**Conclusion:** The existing index supports the status filter, while sorting remains a separate operation. Further testing is needed before concluding that an additional index improves performance.

### Query 2: Index Optimisation Test

**Index tested:** `idx_transfers_successful_completed_at`, a partial index on `completed_at DESC` for successful transfers with a non-null completion timestamp.

**Results:** Before creating the index, the execution time was 0.069 ms. After creating it, the execution time was 0.054 ms. Both executions returned five rows.

**Observation:** PostgreSQL chose a sequential scan after the index was created and retained a separate sort operation. The table currently contains only 10 transfer records, so a sequential scan is a reasonable choice.

**Conclusion:** The second execution was slightly faster, but this small timing difference does not establish that the new index improved performance. The index did not eliminate sorting in the observed plan. Further testing with a larger, representative dataset would be needed to determine its practical value

## Query 3: Daily Transfer Volume

**Purpose:** Group transfers by creation date and currency, calculating the number of transfers and the total transfer amount for each group.

**Baseline execution plan findings**

- **Table access:** Sequential scan on `transfers`.
- **Rows scanned:** 10.
- **Rows returned:** 10 grouped results.
- **Aggregation:** `GroupAggregate`.
- **Sorting:** Quicksort by creation date descending and currency.
- **Execution time:** 0.129 ms.
- **Planning time:** 0.200 ms.
- **Buffer activity:** 7 shared-buffer hits were reported across the execution nodes.

**Analysis:** PostgreSQL read the transfers table, sorted the rows by the grouping keys, and aggregated them. A sequential scan is reasonable because the table currently contains only 10 rows and the query has no selective `WHERE` condition. An ordinary index may not improve this query enough to justify its storage and maintenance costs.

**Potential optimisation:** If the table becomes much larger, a suitable expression index or a date-based reporting strategy could be tested. Any index must match the query's grouping and sorting requirements, and its benefit should be verified using execution plans on a representative dataset.

**Conclusion:** The current plan is simple and fast for the small dataset. The sequential scan alone does not indicate a performance problem.

## Query 4: Failed Transfers

**Purpose:** Retrieve failed transfers, ordered by creation time from newest to oldest, with a maximum of 50 records.

**Baseline execution plan findings**

- **Index used:** `idx_transfers_status_created`.
- **Index condition:** Transfer status equals `failed`.
- **Rows returned:** 1 row.
- **Execution time:** 0.048 ms.
- **Planning time:** 0.135 ms.
- **Buffer activity:** 2 shared-buffer hits.
- **Sorting:** No separate sort node appears in the execution plan.

**Analysis:** PostgreSQL used the existing index to retrieve the failed transfer. The index's ordering by creation time is compatible with the query's descending sort requirement, allowing PostgreSQL to return the result without a separate sort step. The query is already fast on the current dataset.

**Conclusion:** The existing index supports this query effectively. Adding another index for the same filter and ordering is unlikely to be justified without further evidence from a larger, representative dataset.

---

## Scaled Experiment: 200,000 Transfers

The seed dataset (10 transfers) was too small for the planner to prefer indexes, so `bulk-data.sql` added 200,000 synthetic transfers (85% successful, 8% failed, remainder pending/processing/reversed, spread over 365 days; evidence: `screenshots/bulk-data-distribution.png`). For each test in `optimisation-tests.sql`, the candidate index was dropped, the query measured with `EXPLAIN (ANALYZE, BUFFERS)`, the index created, statistics refreshed with `ANALYZE`, and the query measured again.

### Summary of Results

| Test | Query                         | Before                                                                                  | After                                                                                   | Speed-up            |
| ---- | ----------------------------- | --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------- |
| A    | Recent successful transfers   | Parallel Seq Scan + top-N Sort, 3,471 buffers, **960.683 ms**                           | Index Scan (`idx_transfers_successful_completed_at`), no Sort, 23 buffers, **0.082 ms** | ~11,700×            |
| B    | Account statement (account 1) | Bitmap Heap Scan + top-N Sort, 3,469 buffers, **124.437 ms**                            | Index Scan (`idx_transfers_source_created`), no Sort, 23 buffers, **0.103 ms**          | ~1,200×             |
| C    | Daily volume, last 30 days    | Index skip scan (`idx_transfers_status_created`) + Sort, 16,641 buffers, **206.742 ms** | Same plan; new index **not used**, 16,635 buffers, **187.891 ms**                       | none (timing noise) |
| D    | Failed transfers (control)    | Index Scan (`idx_transfers_status_created`), no Sort, 53 buffers, **0.126 ms**          | n/a                                                                                     | already optimal     |

Evidence: `execution-plans/test-a-before.png` … `test-d-control.png`, `execution-plans/index-sizes.png`.

### Test A: Recent Successful Transfers (partial index)

**Before.** With no suitable index, PostgreSQL launched a parallel sequential scan. Two processes read all 3,433 table pages, keeping 170,170 matching rows (85,085 per process) and discarding 29,840. Each process ran a top-N heapsort on `completed_at DESC`, and a Gather Merge combined them to return 20 rows. Reading about 170,000 rows to return 20 cost **960.683 ms**.

**After.** The partial index `idx_transfers_successful_completed_at` stores only successful, completed transfers, already ordered by `completed_at DESC`. PostgreSQL read the first 20 index entries and stopped (Limit). There was no Sort node and no Filter, because the index's `WHERE` clause matches the query. Only 23 pages were touched, and execution took **0.082 ms**.

**Conclusion.** The partial index removed both the full scan and the sort, reducing page reads by about 99% (3,471 to 23). It is also the smallest new index (3,752 kB) because it excludes non-successful rows. **Keep.**

### Test B: Account Statement (composite index)

**Before.** The existing single-column index `idx_transfers_source_account` found the 40,078 transfers from account 1 (Bitmap Index Scan). PostgreSQL then fetched all of them from 3,433 heap pages and sorted them by `created_at` to return 20 rows: **124.437 ms**. The index helped with filtering, but it could not supply the order.

**After.** The composite index `(source_account_id, created_at DESC)` stores each account's transfers already in newest-first order. PostgreSQL used one index search and read 20 entries, with no sort: **0.103 ms**, 23 pages.

**Conclusion.** Column order matters. With the equality column first and the sort column second, one index serves both the `WHERE` and the `ORDER BY` of the query. This pattern suits account statements, a core banking operation. **Keep.**

_Note:_ the synthetic data is skewed (account 1 is the source of about 40,000 transfers, roughly 20% of the table) because only a few accounts exist. With realistic data spread across many accounts, the before case would read fewer rows, but the after case would remain near-constant.

### Test C: Daily Volume, Last 30 Days (index not adopted)

**Before.** Even without `idx_transfers_created_at`, PostgreSQL did **not** use a sequential scan. It used the existing composite index `idx_transfers_status_created` with `Index Searches: 6`. This is PostgreSQL's **skip scan** (available from PostgreSQL 18). Because `status` has only five distinct values, the planner can jump to each status value and range-scan the `created_at` portion, even though the query does not filter on `status`. It read 16,522 rows, but those rows were scattered across the table, so it touched 16,638 buffers (about one per row). It then sorted and grouped them into 31 daily groups: **206.742 ms**.

**After.** The planner **ignored** the new `idx_transfers_created_at` and chose the same skip-scan plan. `pg_stat_user_indexes` confirms the new index was used **0 times**. The time difference (187.891 ms) is cache variation, not a plan change: the buffer counts are almost identical.

**Why.** About 8% of rows match the 30-day range, and they are randomly spread across the table. The planner estimated similar costs for both indexes and kept the existing one. The dominant cost is fetching scattered rows and grouping them, which neither index removes.

**Better alternatives (not yet tested):**

- A covering index `(created_at) INCLUDE (currency, amount)` could allow an **Index Only Scan**, avoiding heap access.
- A **materialised view** or daily summary table, refreshed periodically, would suit a reporting query whose results change once a day.
- **Range partitioning** of `transfers` by `created_at` (see Portfolio 5) would let PostgreSQL skip whole months.

**Conclusion.** Not every plausible index helps. `idx_transfers_created_at` adds 4,408 kB and write overhead with no read benefit. **Drop.**

### Test D: Failed Transfers (control)

The existing `idx_transfers_status_created` matches this query exactly (equality on `status`, order by `created_at DESC`). PostgreSQL read the first 50 matching index entries and stopped, with no sort, touching 53 pages, in **0.126 ms**, even with about 16,000 failed transfers in the table. This confirms that the Portfolio 1 index design already serves this query, so no change is required.

### Index Storage and Usage

Captured from `pg_stat_user_indexes` after the tests:

| Index                                   | Size     | Scans | Decision                                                                               |
| --------------------------------------- | -------- | ----- | -------------------------------------------------------------------------------------- |
| `idx_transfers_status_created`          | 9,704 kB | 15    | Keep: serves Test D and, via skip scan, Test C                                         |
| `transfers_reference_key`               | 6,184 kB | 0     | Keep: enforces the `UNIQUE` reference constraint                                       |
| `idx_transfers_source_created`          | 6,184 kB | 1     | Keep: Test B                                                                           |
| `idx_transfers_created_at`              | 4,408 kB | 0     | **Drop**: never chosen                                                                 |
| `transfers_pkey`                        | 4,408 kB | 12    | Keep: primary key                                                                      |
| `idx_transfers_successful_completed_at` | 3,752 kB | 1     | Keep: Test A                                                                           |
| `idx_transfers_source_account`          | 1,296 kB | 1     | **Consider dropping**: its leading column is covered by `idx_transfers_source_created` |
| `idx_transfers_destination_account`     | 1,296 kB | 0     | Keep: supports foreign-key checks and incoming-transfer lookups                        |

**Trade-off.** Every `INSERT` into `transfers` must update all eight indexes (about 37 MB in total, compared with a heap of about 27 MB at 3,433 pages of 8 kB). For a write-heavy payments table, indexes must justify themselves with measured read benefit. A partial index is a good compromise: it is smaller and only maintained for the rows it covers.

### Key Lessons

1. **Index design must match the query.** A filter-only index (Test B before) still requires a sort; a filter and order composite index removes it.
2. **Partial indexes** suit queries that always target the same subset of rows (Test A).
3. **The planner can reject an index.** Execution plans, not assumptions, decide whether to keep an index (Test C).
4. **Dataset size matters.** The same queries on 10 rows showed no benefit; at 200,000 rows the difference was up to four orders of magnitude.
5. **Measure buffers, not just time.** Timings vary with caching (Test C: 206 ms vs 188 ms with an identical plan), while buffer counts reflect the actual work done.
