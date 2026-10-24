/*
=========================================================
QUICKPAY FINTECH DATABASE
PORTFOLIO 2: BEFORE / AFTER OPTIMISATION TESTS

Prerequisite: run bulk-data.sql first (200,000 transfers).

Method for each test:
  1. Drop the candidate index (baseline state).
  2. Run EXPLAIN (ANALYZE, BUFFERS) -> save as "*-before".
  3. Create the candidate index and ANALYZE.
  4. Run the same EXPLAIN again   -> save as "*-after".
  5. Record execution time, plan nodes, rows scanned,
     and buffers in performance-analysis.md.

Tip: run each EXPLAIN 2-3 times and record the median,
because the first run may include cold-cache reads.
=========================================================
*/

SET search_path TO quickpay, public;


-- ======================================================
-- TEST A: Query 2 - Recent successful transfers
-- Candidate: partial index on completed_at DESC
-- ======================================================

DROP INDEX IF EXISTS quickpay.idx_transfers_successful_completed_at;

-- A1. BEFORE
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, reference, source_account_id,
       destination_account_id, amount, currency,
       status, completed_at
FROM quickpay.transfers
WHERE status = 'successful'
  AND completed_at IS NOT NULL
ORDER BY completed_at DESC
LIMIT 20;

CREATE INDEX idx_transfers_successful_completed_at
ON quickpay.transfers (completed_at DESC)
WHERE status = 'successful'
  AND completed_at IS NOT NULL;

ANALYZE quickpay.transfers;

-- A2. AFTER (expect: Index Scan + Limit, no Sort node)
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, reference, source_account_id,
       destination_account_id, amount, currency,
       status, completed_at
FROM quickpay.transfers
WHERE status = 'successful'
  AND completed_at IS NOT NULL
ORDER BY completed_at DESC
LIMIT 20;


-- ======================================================
-- TEST B: Query 5 - Account statement (new query)
-- "Last 20 outgoing transfers for one account"
-- Existing idx_transfers_source_account filters by
-- account but cannot provide the ORDER BY created_at.
-- Candidate: composite index (source_account_id, created_at DESC)
-- ======================================================

DROP INDEX IF EXISTS quickpay.idx_transfers_source_created;

-- B1. BEFORE
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, reference, destination_account_id,
       amount, status, created_at
FROM quickpay.transfers
WHERE source_account_id = 1
ORDER BY created_at DESC
LIMIT 20;

CREATE INDEX idx_transfers_source_created
ON quickpay.transfers (source_account_id, created_at DESC);

ANALYZE quickpay.transfers;

-- B2. AFTER (expect: Index Scan on idx_transfers_source_created, no Sort)
EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, reference, destination_account_id,
       amount, status, created_at
FROM quickpay.transfers
WHERE source_account_id = 1
ORDER BY created_at DESC
LIMIT 20;


-- ======================================================
-- TEST C: Query 3 - Daily volume for the last 30 days
-- Candidate: index on created_at to support the range filter
-- ======================================================

DROP INDEX IF EXISTS quickpay.idx_transfers_created_at;

-- C1. BEFORE
EXPLAIN (ANALYZE, BUFFERS)
SELECT created_at::date AS transfer_date, currency,
       COUNT(*) AS transfer_count,
       SUM(amount) AS total_transfer_amount
FROM quickpay.transfers
WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY created_at::date, currency
ORDER BY transfer_date DESC, currency;

CREATE INDEX idx_transfers_created_at
ON quickpay.transfers (created_at);

ANALYZE quickpay.transfers;

-- C2. AFTER (expect: Bitmap/Index Scan on idx_transfers_created_at)
EXPLAIN (ANALYZE, BUFFERS)
SELECT created_at::date AS transfer_date, currency,
       COUNT(*) AS transfer_count,
       SUM(amount) AS total_transfer_amount
FROM quickpay.transfers
WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY created_at::date, currency
ORDER BY transfer_date DESC, currency;


-- ======================================================
-- TEST D: Query 4 - Failed transfers (control test)
-- No new index. Shows the existing composite index
-- idx_transfers_status_created already serves this query.
-- ======================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT transfer_id, reference, source_account_id,
       destination_account_id, amount, currency,
       created_at, description
FROM quickpay.transfers
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 50;


-- ======================================================
-- Index size / overhead evidence
-- ======================================================

SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS times_used
FROM pg_stat_user_indexes
WHERE schemaname = 'quickpay'
  AND relname = 'transfers'
ORDER BY pg_relation_size(indexrelid) DESC;
