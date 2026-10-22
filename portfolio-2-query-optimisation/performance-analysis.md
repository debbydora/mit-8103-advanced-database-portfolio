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
