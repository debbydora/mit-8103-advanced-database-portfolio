/*
=========================================================
QUICKPAY FINTECH DATABASE
PORTFOLIO 2: BULK TEST DATA

Purpose:
The seed data contains only 10 transfers, which is too
small for PostgreSQL to prefer an index over a sequential
scan. This script generates 200,000 synthetic transfers
between the existing accounts so that execution plans
reflect realistic data volumes.

All generated rows use the reference prefix 'BULK-' so
they can be removed safely (see cleanup at the bottom).

Run time: a few seconds on a local/Render database.
=========================================================
*/

SET search_path TO quickpay, public;

-- Make the random data reproducible between runs.
SELECT setseed(0.42);

-- Single self-contained INSERT (no WITH clause) so that
-- DBeaver cannot split it into separate statements.
INSERT INTO quickpay.transfers (
    source_account_id,
    destination_account_id,
    amount,
    currency,
    status,
    reference,
    description,
    created_at,
    completed_at
)
SELECT
    ids[src_idx],
    -- offset guarantees destination <> source
    ids[1 + ((src_idx - 1 + dst_offset) % CARDINALITY(ids))],
    ROUND((100 + RANDOM() * 499900)::NUMERIC, 2),
    'NGN',
    CASE
        WHEN r_status < 0.85 THEN 'successful'
        WHEN r_status < 0.93 THEN 'failed'
        WHEN r_status < 0.97 THEN 'pending'
        WHEN r_status < 0.99 THEN 'processing'
        ELSE 'reversed'
    END,
    'BULK-' || LPAD(n::TEXT, 7, '0'),
    'Synthetic load-test transfer',
    created,
    CASE
        WHEN r_status < 0.85 THEN created + (RANDOM() * INTERVAL '5 minutes')
        ELSE NULL
    END
FROM (
    SELECT
        g AS n,
        a.ids,
        -- random source position, and an offset so destination <> source
        1 + FLOOR(RANDOM() * CARDINALITY(a.ids))::INT AS src_idx,
        1 + FLOOR(RANDOM() * (CARDINALITY(a.ids) - 1))::INT AS dst_offset,
        RANDOM() AS r_status,
        -- spread transfers over the last 365 days
        CURRENT_TIMESTAMP - (RANDOM() * INTERVAL '365 days') AS created
    FROM generate_series(1, 200000) AS g
    CROSS JOIN (
        SELECT ARRAY_AGG(account_id ORDER BY account_id) AS ids
        FROM quickpay.accounts
    ) AS a
) AS gen;

-- Refresh planner statistics so plans use the new row counts.
ANALYZE quickpay.transfers;

-- Verify the data distribution.
SELECT status, COUNT(*) AS transfer_count
FROM quickpay.transfers
GROUP BY status
ORDER BY transfer_count DESC;


