
-- Portfolio 5: Distributed and Cloud Database Exercise
-- Case study: QuickPay
-- Purpose: Verify cloud database connectivity and structure.
-- These tests are read-only.

-- Test 1: Confirm the connected database and PostgreSQL version.
SELECT
    current_database() AS database_name,
    current_user AS connected_user,
    version() AS postgresql_version;

-- Test 2: Confirm the active schema.
SELECT current_schema() AS active_schema;

-- Test 3: Check the five expected QuickPay tables.
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'quickpay'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- Test 4: Count records in each table.
SELECT 'customers' AS table_name, COUNT(*) AS record_count
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

-- Test 5: Check the database server timestamp.
SELECT
    CURRENT_TIMESTAMP AS server_timestamp,
    CURRENT_SETTING('transaction_isolation') AS transaction_isolation;
