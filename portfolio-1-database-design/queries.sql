/*
=========================================================
QUICKPAY FINTECH DATABASE
PORTFOLIO 1: DATABASE DESIGN AND IMPLEMENTATION
File: queries.sql

Purpose:
Verify the database structure, inspect seeded records,
check data integrity, and generate useful reports.

Schema: quickpay
=========================================================
*/

-- ======================================================
-- SECTION 1: DATABASE AND SCHEMA VERIFICATION
-- ======================================================

-- 1. Confirm the connected database and schema
SELECT
    current_database() AS database_name,
    current_schema() AS current_schema;

-- 2. List the five Quickpay tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'quickpay'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;


-- ======================================================
-- SECTION 2: SEEDED DATA AND RECORD COUNTS
-- ======================================================

-- 3. Count records in all five tables
SELECT 'customers' AS table_name, COUNT(*) AS total_records
FROM quickpay.customers
UNION ALL
SELECT 'accounts', COUNT(*)
FROM quickpay.accounts
UNION ALL
SELECT 'transfers', COUNT(*)
FROM quickpay.transfers
UNION ALL
SELECT 'ledger_entries', COUNT(*)
FROM quickpay.ledger_entries
UNION ALL
SELECT 'audit_logs', COUNT(*)
FROM quickpay.audit_logs
ORDER BY table_name;


-- ======================================================
-- SECTION 3: CUSTOMER QUERIES
-- ======================================================

-- 4. View all customers
SELECT *
FROM quickpay.customers
ORDER BY customer_id;

-- 5. Count customers by status
SELECT status, COUNT(*) AS total_customers
FROM quickpay.customers
GROUP BY status
ORDER BY status;

-- 6. Check for duplicate email addresses,
-- ignoring differences in letter case and surrounding spaces
SELECT LOWER(TRIM(email)) AS normalized_email,
       COUNT(*) AS occurrences
FROM quickpay.customers
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1;


-- ======================================================
-- SECTION 4: ACCOUNT QUERIES
-- ======================================================

-- 7. View all accounts
SELECT *
FROM quickpay.accounts
ORDER BY account_id;

-- 8. Count accounts by status
SELECT status, COUNT(*) AS total_accounts
FROM quickpay.accounts
GROUP BY status
ORDER BY status;

-- 9. Check account numbers for duplicates
SELECT account_number, COUNT(*) AS occurrences
FROM quickpay.accounts
GROUP BY account_number
HAVING COUNT(*) > 1;

-- 10. Find accounts with missing customer records
SELECT a.account_id, a.customer_id
FROM quickpay.accounts AS a
LEFT JOIN quickpay.customers AS c
    ON c.customer_id = a.customer_id
WHERE c.customer_id IS NULL;

-- 11. List customers and their accounts,
-- including customers who have no account
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance,
    a.currency
FROM quickpay.customers AS c
LEFT JOIN quickpay.accounts AS a
    ON a.customer_id = c.customer_id
ORDER BY c.customer_id, a.account_id;


-- ======================================================
-- SECTION 5: TRANSFER QUERIES
-- ======================================================

-- 12. View all transfers
SELECT *
FROM quickpay.transfers
ORDER BY transfer_id;

-- 13. Count transfers by status
SELECT status, COUNT(*) AS total_transfers
FROM quickpay.transfers
GROUP BY status
ORDER BY status;

-- 14. Total value of successful transfers by currency
SELECT
    currency,
    COUNT(*) AS total_transfers,
    SUM(amount) AS total_amount
FROM quickpay.transfers
WHERE status = 'successful'
GROUP BY currency
ORDER BY currency;

-- 15. Display transfer details with source and destination accounts
SELECT
    t.transfer_id,
    t.reference,
    t.amount,
    t.currency,
    t.status,
    src.account_number AS source_account,
    dest.account_number AS destination_account
FROM quickpay.transfers AS t
JOIN quickpay.accounts AS src
    ON src.account_id = t.source_account_id
JOIN quickpay.accounts AS dest
    ON dest.account_id = t.destination_account_id
ORDER BY t.transfer_id;

-- 16. Find transfers with missing source or destination accounts
SELECT
    t.transfer_id,
    t.source_account_id,
    t.destination_account_id
FROM quickpay.transfers AS t
LEFT JOIN quickpay.accounts AS src
    ON src.account_id = t.source_account_id
LEFT JOIN quickpay.accounts AS dest
    ON dest.account_id = t.destination_account_id
WHERE src.account_id IS NULL
   OR dest.account_id IS NULL;


-- ======================================================
-- SECTION 6: LEDGER QUERIES
-- ======================================================

-- 17. View all ledger entries
SELECT *
FROM quickpay.ledger_entries
ORDER BY ledger_entry_id;

-- 18. Summarize debit and credit entries
SELECT
    entry_type,
    currency,
    COUNT(*) AS total_entries,
    SUM(amount) AS total_amount
FROM quickpay.ledger_entries
GROUP BY entry_type, currency
ORDER BY currency, entry_type;

-- 19. Find ledger entries with missing transfers or accounts
SELECT
    le.ledger_entry_id,
    le.transfer_id,
    le.account_id
FROM quickpay.ledger_entries AS le
LEFT JOIN quickpay.transfers AS t
    ON t.transfer_id = le.transfer_id
LEFT JOIN quickpay.accounts AS a
    ON a.account_id = le.account_id
WHERE t.transfer_id IS NULL
   OR a.account_id IS NULL;

-- 20. Check successful transfers against their ledger entries
SELECT
    t.transfer_id,
    t.reference,
    t.amount,
    t.currency
FROM quickpay.transfers AS t
LEFT JOIN quickpay.ledger_entries AS le
    ON le.transfer_id = t.transfer_id
WHERE t.status = 'successful'
GROUP BY
    t.transfer_id,
    t.reference,
    t.amount,
    t.currency,
    t.source_account_id,
    t.destination_account_id
HAVING COUNT(le.ledger_entry_id) <> 2
    OR COUNT(*) FILTER (
        WHERE le.entry_type = 'debit'
          AND le.account_id = t.source_account_id
          AND le.amount = t.amount
          AND le.currency = t.currency
    ) <> 1
    OR COUNT(*) FILTER (
        WHERE le.entry_type = 'credit'
          AND le.account_id = t.destination_account_id
          AND le.amount = t.amount
          AND le.currency = t.currency
    ) <> 1;


-- ======================================================
-- SECTION 7: AUDIT LOG QUERIES
-- ======================================================

-- 21. View all audit logs
SELECT *
FROM quickpay.audit_logs
ORDER BY audit_log_id;

-- 22. Display audit logs with the actor's name
SELECT
    al.audit_log_id,
    al.action,
    al.entity_type,
    al.entity_id,
    al.details,
    al.created_at,
    c.customer_id AS actor_customer_id,
    c.first_name,
    c.last_name
FROM quickpay.audit_logs AS al
LEFT JOIN quickpay.customers AS c
    ON c.customer_id = al.actor_customer_id
ORDER BY al.created_at DESC;

-- 23. Find audit logs with invalid customer references
SELECT
    al.audit_log_id,
    al.actor_customer_id
FROM quickpay.audit_logs AS al
LEFT JOIN quickpay.customers AS c
    ON c.customer_id = al.actor_customer_id
WHERE al.actor_customer_id IS NOT NULL
  AND c.customer_id IS NULL;


-- ======================================================
-- SECTION 8: CONSTRAINTS AND INDEX VERIFICATION
-- ======================================================

-- 24. List constraints on the five tables
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints AS tc
WHERE tc.constraint_schema = 'quickpay'
  AND tc.table_name IN (
      'customers',
      'accounts',
      'transfers',
      'ledger_entries',
      'audit_logs'
  )
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- 25. List indexes on the five tables
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'quickpay'
ORDER BY tablename, indexname;



