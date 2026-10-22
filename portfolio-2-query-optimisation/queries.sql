
/*
=========================================================
QUICKPAY FINTECH DATABASE
PORTFOLIO 2: QUERY PROCESSING AND OPTIMISATION

Purpose:
Execute realistic banking queries and inspect their
baseline query execution plans.
=========================================================
*/

-- ======================================================
-- QUERY 1: Retrieve a customer's accounts
-- ======================================================

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance,
    a.currency,
    a.status AS account_status
FROM quickpay.customers AS c
JOIN quickpay.accounts AS a
    ON a.customer_id = c.customer_id
WHERE c.customer_id = 5
ORDER BY a.account_id;


-- ======================================================
-- QUERY 2: Retrieve recent completed transfers
-- ======================================================

SELECT
    t.transfer_id,
    t.reference,
    t.source_account_id,
    t.destination_account_id,
    t.amount,
    t.currency,
    t.status,
    t.completed_at
FROM quickpay.transfers AS t
WHERE t.status = 'successful'
  AND t.completed_at IS NOT NULL
ORDER BY t.completed_at DESC
LIMIT 20;


-- ======================================================
-- QUERY 3: Calculate daily transfer volume
-- ======================================================

SELECT
    t.created_at::date AS transfer_date,
    t.currency,
    COUNT(*) AS transfer_count,
    SUM(t.amount) AS total_transfer_amount
FROM quickpay.transfers AS t
GROUP BY t.created_at::date, t.currency
ORDER BY transfer_date DESC, t.currency;


-- ======================================================
-- QUERY 4: Monitor failed transfers
-- ======================================================

SELECT
    t.transfer_id,
    t.reference,
    t.source_account_id,
    t.destination_account_id,
    t.amount,
    t.currency,
    t.created_at,
    t.description
FROM quickpay.transfers AS t
WHERE t.status = 'failed'
ORDER BY t.created_at DESC
LIMIT 50;
