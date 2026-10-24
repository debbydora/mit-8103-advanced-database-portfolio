/*
=========================================================
QUICKPAY FINTECH DATABASE
PORTFOLIO 5: PARTITIONING (PRACTICAL DEMONSTRATION)

Purpose:
Demonstrate the data-distribution techniques discussed in
the distributed-database analysis, on the real QuickPay
transfers data (about 200,000 rows from Portfolio 2):

  Part A  RANGE partitioning by month (created_at)
          -> partition pruning, data retention
  Part B  HASH partitioning by source_account_id
          -> how a sharding key spreads data across
             4 "shards" (simulated on one server)

The original quickpay.transfers table is NOT modified.
Copies are created as new tables, so the demo is safe and
can be removed with the cleanup at the bottom.
=
=========================================================
*/

SET search_path TO quickpay, public;


-- ======================================================
-- PART A: RANGE PARTITIONING BY MONTH
-- ======================================================

-- STEP A1: Create the partitioned parent table.
-- The partition key (created_at) must be part of the
-- primary key, so the key is (transfer_id, created_at).
CREATE TABLE quickpay.transfers_by_month (
    transfer_id            BIGINT        NOT NULL,
    source_account_id      BIGINT        NOT NULL,
    destination_account_id BIGINT        NOT NULL,
    amount                 NUMERIC(19,4) NOT NULL CHECK (amount > 0),
    currency               CHAR(3)       NOT NULL,
    status                 VARCHAR(20)   NOT NULL,
    reference              VARCHAR(100)  NOT NULL,
    description            TEXT,
    created_at             TIMESTAMPTZ   NOT NULL,
    completed_at           TIMESTAMPTZ,
    PRIMARY KEY (transfer_id, created_at)
) PARTITION BY RANGE (created_at);


-- STEP A2: Create one partition per month, plus a DEFAULT
-- partition that catches anything outside these ranges.
CREATE TABLE quickpay.transfers_2025_10 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE quickpay.transfers_2025_11 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE quickpay.transfers_2025_12 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE quickpay.transfers_2026_01 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE quickpay.transfers_2026_02 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE quickpay.transfers_2026_03 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE quickpay.transfers_2026_04 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE quickpay.transfers_2026_05 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE quickpay.transfers_2026_06 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE quickpay.transfers_2026_07 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE quickpay.transfers_2026_08 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE quickpay.transfers_2026_09 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE quickpay.transfers_2026_10 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE quickpay.transfers_2026_11 PARTITION OF quickpay.transfers_by_month FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE quickpay.transfers_default  PARTITION OF quickpay.transfers_by_month DEFAULT;


-- STEP A3: Copy all transfers in. PostgreSQL routes each
-- row to the correct monthly partition automatically.
INSERT INTO quickpay.transfers_by_month
SELECT transfer_id, source_account_id, destination_account_id,
       amount, currency, status, reference, description,
       created_at, completed_at
FROM quickpay.transfers;

ANALYZE quickpay.transfers_by_month;


-- STEP A4: Show how rows were distributed.
-- [SCREENSHOT 05-range-partition-distribution]
SELECT
    tableoid::regclass AS partition_name,
    COUNT(*)           AS row_count,
    MIN(created_at)::date AS earliest,
    MAX(created_at)::date AS latest
FROM quickpay.transfers_by_month
GROUP BY tableoid
ORDER BY MIN(created_at);


-- STEP A5: Partition pruning - BEFORE (original, unpartitioned table).
-- Query: all transfers in August 2026.
-- [SCREENSHOT 06a-pruning-unpartitioned]
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM quickpay.transfers
WHERE created_at >= '2026-08-01' AND created_at < '2026-09-01';


-- STEP A6: Partition pruning - AFTER (partitioned table).
-- Expect: only transfers_2026_08 is scanned.
-- [SCREENSHOT 06b-pruning-partitioned]
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM quickpay.transfers_by_month
WHERE created_at >= '2026-08-01' AND created_at < '2026-09-01';


-- STEP A7: Data retention - archive the oldest month.
-- DETACH removes the partition from the parent instantly
-- (no row-by-row DELETE). It still exists as its own table
-- and could be moved to cheaper storage or dropped.
-- [SCREENSHOT 07-detach-partition]
SELECT COUNT(*) AS rows_before_detach FROM quickpay.transfers_by_month;

ALTER TABLE quickpay.transfers_by_month
    DETACH PARTITION quickpay.transfers_2025_10;

SELECT COUNT(*) AS rows_after_detach  FROM quickpay.transfers_by_month;
SELECT COUNT(*) AS rows_in_archived_table FROM quickpay.transfers_2025_10;


-- ======================================================
-- PART B: HASH PARTITIONING (SHARDING SIMULATION)
-- source_account_id acts as the sharding key. Each hash
-- partition represents one shard; on a distributed system
-- (e.g. Citus) each would live on a different server.
-- ======================================================

-- STEP B1: Create the hash-partitioned table and 4 "shards".
CREATE TABLE quickpay.transfers_by_account (
    transfer_id            BIGINT        NOT NULL,
    source_account_id      BIGINT        NOT NULL,
    destination_account_id BIGINT        NOT NULL,
    amount                 NUMERIC(19,4) NOT NULL,
    status                 VARCHAR(20)   NOT NULL,
    created_at             TIMESTAMPTZ   NOT NULL,
    PRIMARY KEY (transfer_id, source_account_id)
) PARTITION BY HASH (source_account_id);

CREATE TABLE quickpay.transfers_shard_0 PARTITION OF quickpay.transfers_by_account FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE quickpay.transfers_shard_1 PARTITION OF quickpay.transfers_by_account FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE quickpay.transfers_shard_2 PARTITION OF quickpay.transfers_by_account FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE quickpay.transfers_shard_3 PARTITION OF quickpay.transfers_by_account FOR VALUES WITH (MODULUS 4, REMAINDER 3);


-- STEP B2: Load the data.
INSERT INTO quickpay.transfers_by_account
SELECT transfer_id, source_account_id, destination_account_id,
       amount, status, created_at
FROM quickpay.transfers;

ANALYZE quickpay.transfers_by_account;


-- STEP B3: Which accounts landed on which shard, and how balanced is it?
-- [SCREENSHOT 08-shard-distribution]
SELECT
    tableoid::regclass                         AS shard,
    COUNT(*)                                   AS row_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_rows,
    ARRAY_AGG(DISTINCT source_account_id ORDER BY source_account_id) AS accounts
FROM quickpay.transfers_by_account
GROUP BY tableoid
ORDER BY shard;


-- STEP B4: Query WITH the sharding key -> routed to ONE shard.
-- [SCREENSHOT 09a-single-shard-query]
EXPLAIN (ANALYZE)
SELECT COUNT(*), SUM(amount)
FROM quickpay.transfers_by_account
WHERE source_account_id = 3;


-- STEP B5: Query WITHOUT the sharding key -> must visit ALL shards
-- (a "scatter-gather" query in a distributed database).
-- [SCREENSHOT 09b-all-shards-query]
EXPLAIN (ANALYZE)
SELECT COUNT(*), SUM(amount)
FROM quickpay.transfers_by_account
WHERE status = 'failed';



