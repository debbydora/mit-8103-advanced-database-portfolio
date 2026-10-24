# Portfolio 5: Partitioning and Sharding Demonstration

## 1. Purpose

The distributed-database analysis discusses data distribution conceptually. This exercise demonstrates it practically on the Render-hosted QuickPay database, using the 200,011 transfers from Portfolio 2:

- **Range partitioning** by month (`created_at`): partition pruning and data retention.
- **Hash partitioning** by `source_account_id`: a single-server simulation of **sharding**, showing data placement, shard routing, and scatter-gather queries.

The original `quickpay.transfers` table was not modified; data was copied into new partitioned tables (`partitioning.sql`). Raw outputs are in `results/partitioning-results.txt`.

## 2. Range Partitioning by Month

### 2.1 Setup and Distribution

`transfers_by_month` was created with `PARTITION BY RANGE (created_at)`, with 14 monthly partitions (October 2025 to November 2026) and a `DEFAULT` partition. Because the partition key must be part of every unique constraint, the primary key became `(transfer_id, created_at)`.

All **200,011** rows were copied (original and partitioned counts matched), and PostgreSQL routed each row automatically:

| Partition             | Rows   | Partition           | Rows   |
| --------------------- | ------ | ------------------- | ------ |
| 2025_10 (from 24 Oct) | 4,198  | 2026_04             | 16,455 |
| 2025_11               | 16,444 | 2026_05             | 16,831 |
| 2025_12               | 17,160 | 2026_06             | 16,340 |
| 2026_01               | 16,998 | 2026_07             | 16,796 |
| 2026_02               | 15,265 | 2026_08             | 16,959 |
| 2026_03               | 17,017 | 2026_09             | 16,705 |
|                       |        | 2026_10 (to 24 Oct) | 12,843 |

Full months hold about 16,000–17,000 rows; February is lower (28 days), and the first and last months are partial. The `DEFAULT` and November 2026 partitions are empty, confirming every row matched a defined range.

### 2.2 Partition Pruning

Query: count and total of all August 2026 transfers.

|                            | Unpartitioned `transfers`                                                                    | Partitioned `transfers_by_month`         |
| -------------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Plan                       | Index Scan (skip scan, 11 searches) on `idx_transfers_status_created` across the whole table | **Seq Scan on `transfers_2026_08` only** |
| Rows returned to aggregate | 16,959                                                                                       | 16,959                                   |
| Buffers                    | 17,092 (15,081 hit + **2,011 read from disk**)                                               | **291** (all hit)                        |
| Execution time             | **934.662 ms**                                                                               | **7.880 ms**                             |

The planner eliminated the other 14 partitions at planning time (**partition pruning**) and scanned only August. Because the August partition contains only August rows, a simple sequential scan was ideal, with no filter waste. The unpartitioned table had to locate August rows scattered across the whole heap, touching 59× more pages and needing disk reads.

**Result:** about **119× faster** and **98% fewer pages**, for the same answer.

### 2.3 Data Retention with DETACH

| Measure                                    | Rows    |
| ------------------------------------------ | ------- |
| Before detach                              | 200,011 |
| After `DETACH PARTITION transfers_2025_10` | 195,813 |
| Rows in the detached (archived) table      | 4,198   |

A whole month was removed from the live table as a single metadata operation, with no row-by-row `DELETE`, no table bloat, and no `VACUUM` needed. The detached table still exists and can be exported to cheaper storage or dropped. This suits financial record-retention policies (keep N years online, then archive).

## 3. Hash Partitioning as a Sharding Simulation

### 3.1 Setup and Distribution

`transfers_by_account` was created with `PARTITION BY HASH (source_account_id)` and four partitions (`MODULUS 4`), each representing a **shard**. In a distributed PostgreSQL system (for example Citus), each shard would reside on a separate node; here they share one server, so the exercise demonstrates **data placement and query routing**, not network distribution.

| Shard   | Rows       | Share     | Accounts   |
| ------- | ---------- | --------- | ---------- |
| shard_0 | 40,079     | 20.0%     | {1}        |
| shard_1 | **79,948** | **40.0%** | **{3, 5}** |
| shard_2 | 40,280     | 20.1%     | {2}        |
| shard_3 | 39,704     | 19.9%     | {4}        |

Every account lives entirely on **one** shard, so all of an account's transfers are co-located.

**Hot shard.** With only five source accounts and four shards, the hash function placed accounts 3 and 5 together, giving shard_1 twice the data (and, in production, twice the load) of the others. Hashing balances well only when there are many more key values than shards. With millions of customer accounts the distribution would converge to about 25% each. Mitigations for skew include more shards than nodes (allowing rebalancing) and avoiding low-cardinality shard keys.

### 3.2 Shard Routing vs Scatter-Gather

| Query                                                  | Shards scanned                          | Buffers | Execution time |
| ------------------------------------------------------ | --------------------------------------- | ------- | -------------- |
| `WHERE source_account_id = 3` (**includes shard key**) | **1** (`shard_1`)                       | 820     | **82.789 ms**  |
| `WHERE status = 'failed'` (**no shard key**)           | **4** (Parallel Append over all shards) | 2,052   | **327.395 ms** |

**With the shard key**, the planner computed `hash(3) mod 4` and routed the query to `shard_1` alone. The filter removed 40,214 rows, which belong to account 5, its shard neighbour.

**Without the shard key**, the planner could not know where failed transfers live, so it scanned all four shards (in parallel) and combined partial aggregates (**scatter-gather**). It did about 2.5× the I/O and took about 4× the time. On a real cluster, this also means a network round-trip to every node, and the slowest node determines response time.

## 4. Implications for QuickPay

1. **Choose the shard key from the dominant access pattern.** Most QuickPay queries are per-account (statements, balances, history), so `account_id` (or `customer_id`) is a suitable key: these queries hit one shard.
2. **Cross-account operations span shards.** A transfer between accounts on different shards requires a distributed transaction (two-phase commit), losing the single-node ACID simplicity shown in Portfolio 3. Sharding by `customer_id`, so a customer's accounts are co-located, reduces but does not eliminate this.
3. **Reporting queries become scatter-gather.** Company-wide reports (failed transfers, daily volume) should run on a read replica, an analytics store, or pre-aggregated tables rather than across all shards.
4. **Range partitioning is valuable even without sharding.** Monthly partitions of a single PostgreSQL instance gave a large performance gain and easy retention, with none of the consistency costs of distribution. It is the recommended first step before sharding.
5. **Partitioning and indexing combine.** Partitioned tables can carry per-partition indexes (e.g. on `source_account_id, created_at`) to also accelerate per-account queries within a month.

## 5. Limitations

- All partitions and shards are on **one** Render instance; network latency, node failure, and rebalancing were not tested.
- The low number of accounts exaggerates shard skew.
- The partitioned tables are copies; migrating the live `transfers` table would also require recreating foreign keys from `ledger_entries` (which reference `transfer_id` alone) and handling the composite primary key.
- Timings come from single runs on a shared cloud instance, so page counts (buffers) are the more reliable comparison.

## 6. Cleanup

```sql
DROP TABLE IF EXISTS quickpay.transfers_by_month CASCADE;
DROP TABLE IF EXISTS quickpay.transfers_2025_10;
DROP TABLE IF EXISTS quickpay.transfers_by_account CASCADE;
```
