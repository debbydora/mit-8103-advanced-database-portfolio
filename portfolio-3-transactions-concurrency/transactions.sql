
-- Portfolio 3: Transactions and Concurrency
-- Exercise 1: Atomic funds transfer
-- Transfer amount: NGN 1,000.00
-- Accounts: 1 -> 2

BEGIN;

DO $$
DECLARE
    debit_rows INTEGER;
    credit_rows INTEGER;
BEGIN
    -- Debit the source account only if it is active
    -- and has enough funds.
    UPDATE quickpay.accounts
    SET balance = balance - 1000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id = 1
      AND status = 'active'
      AND currency = 'NGN'
      AND balance >= 1000.00;

    GET DIAGNOSTICS debit_rows = ROW_COUNT;

    IF debit_rows <> 1 THEN
        RAISE EXCEPTION
            'Transfer failed: source account is inactive, missing, or has insufficient funds';
    END IF;

    -- Credit the destination account only if it is active.
    UPDATE quickpay.accounts
    SET balance = balance + 1000.00,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id = 2
      AND status = 'active'
      AND currency = 'NGN';

    GET DIAGNOSTICS credit_rows = ROW_COUNT;

    IF credit_rows <> 1 THEN
        RAISE EXCEPTION
            'Transfer failed: destination account is inactive, missing, or has a different currency';
    END IF;

    RAISE NOTICE 'Transfer completed successfully';
END $$;

COMMIT;


-- Exercise 2:  Transaction rollback
-- This test changes a balance temporarily, then undoes the change.

BEGIN;

UPDATE quickpay.accounts
SET balance = balance - 500.00
WHERE account_id = 1
  AND status = 'active'
  AND balance >= 500.00;

-- Inspect the temporary balance change.
SELECT account_id, balance
FROM quickpay.accounts
WHERE account_id = 1;

-- Undo the update so the original balance is restored.
ROLLBACK;

-- Confirm that the original balance is restored.
SELECT account_id, balance
FROM quickpay.accounts
WHERE account_id = 1;


-- Exercise 3:  COMMIT versus ROLLBACK
-- This safe test uses a temporary database setting rather than
-- changing any customer account balances.

BEGIN;

SET LOCAL application_name = 'QuickPay_Portfolio3_Transaction_Test';

SELECT
    current_setting('application_name') AS transaction_test;

ROLLBACK;

-- After rollback, the transaction-local setting is reverted.
SELECT
    current_setting('application_name') AS application_name_after_rollback;



-- Exercise 4: Row-level locking 
-- Run this in DBeaver to inspect how PostgreSQL locks an account row.
-- Do not run this alongside an unfinished transaction.

BEGIN;

SELECT
    account_id,
    balance
FROM quickpay.accounts
WHERE account_id = 1
FOR UPDATE;

-- FOR UPDATE locks this row until the transaction ends.
-- Another transaction attempting to update this row must wait.

ROLLBACK;


-- Exercise 5: COMMIT
-- This test changes a session setting, not account balances.

BEGIN;

SET application_name = 'QuickPay_Portfolio3_Commit_Test';

COMMIT;

-- Verify that the setting persists after COMMIT.
SELECT
    current_setting('application_name') AS committed_setting;

-- Restore the normal session setting after verification.
RESET application_name;


-- Exercise 6: Demonstrate transaction isolation
-- Session A makes an uncommitted change.
-- Session B should still see the last committed balance.

BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

UPDATE quickpay.accounts
SET balance = balance + 1.00
WHERE account_id = 1;

-- Session A should see the temporary balance of 150001.0000.
SELECT account_id, balance
FROM quickpay.accounts
WHERE account_id = 1;

-- IMPORTANT: Keep this transaction open while testing Session B.
-- After Session B checks the balance, return here and run ROLLBACK.

