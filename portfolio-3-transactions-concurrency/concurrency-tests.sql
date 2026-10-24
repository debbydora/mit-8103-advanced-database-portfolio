/*
=========================================================
QUICKPAY FINTECH DATABASE
PORTFOLIO 3 (PART 2): ATOMIC TRANSFERS AND CONCURRENCY

  7. Full atomic transfer (accounts + transfers + ledger) - COMMIT
  8. Failed transfer (insufficient funds) - automatic ROLLBACK
  9. Lost update anomaly (READ COMMITTED, two sessions)
 10. Lost update prevented with SELECT ... FOR UPDATE
 11. Deadlock detection (two sessions)
 12. Serialization failure (REPEATABLE READ)


=========================================================
*/

SET search_path TO quickpay, public;

-- Baseline balances before any test [SCREENSHOT 06-baseline-balances]
SELECT account_id, account_number, balance, currency, status
FROM quickpay.accounts
WHERE account_id IN (1, 2)
ORDER BY account_id;


-- ======================================================
-- EXERCISE 7: Full atomic transfer - COMMIT
-- NGN 1,000 from account 1 to account 2.
-- All five writes succeed together or not at all.
-- ======================================================

BEGIN;

DO $$
DECLARE
    v_transfer_id BIGINT;
    v_amount      NUMERIC(19,4) := 1000.00;    ROLLBACK;
    v_src         BIGINT := 1;
    v_dst         BIGINT := 2;
BEGIN
    -- Lock both rows in a fixed order (lowest id first) to avoid deadlocks.
    PERFORM 1 FROM quickpay.accounts
    WHERE account_id IN (v_src, v_dst)
    ORDER BY account_id
    FOR UPDATE;

    -- Debit (guarded: active, NGN, sufficient funds)
    UPDATE quickpay.accounts
    SET balance = balance - v_amount, updated_at = CURRENT_TIMESTAMP
    WHERE account_id = v_src AND status = 'active'
      AND currency = 'NGN' AND balance >= v_amount;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer failed: source inactive or insufficient funds';
    END IF;

    -- Credit
    UPDATE quickpay.accounts
    SET balance = balance + v_amount, updated_at = CURRENT_TIMESTAMP
    WHERE account_id = v_dst AND status = 'active' AND currency = 'NGN';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer failed: destination inactive or wrong currency';
    END IF;

    -- Record the transfer
    INSERT INTO quickpay.transfers
        (source_account_id, destination_account_id, amount, currency,
         status, reference, description, completed_at)
    VALUES
        (v_src, v_dst, v_amount, 'NGN', 'successful',
         'P3-TXN-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
         'Portfolio 3 atomic transfer test', CURRENT_TIMESTAMP)
    RETURNING transfer_id INTO v_transfer_id;

    -- Double-entry ledger: one debit, one credit
    INSERT INTO quickpay.ledger_entries (transfer_id, account_id, entry_type, amount, currency)
    VALUES (v_transfer_id, v_src, 'debit',  v_amount, 'NGN'),
           (v_transfer_id, v_dst, 'credit', v_amount, 'NGN');

    RAISE NOTICE 'Transfer % completed', v_transfer_id;
END $$;

COMMIT;

-- Verify [SCREENSHOT 07-atomic-transfer-commit]
-- Expect: account 1 down 1,000; account 2 up 1,000;
-- one transfer row; two ledger rows that balance.
SELECT account_id, balance FROM quickpay.accounts
WHERE account_id IN (1, 2) ORDER BY account_id;

SELECT t.transfer_id, t.reference, t.amount, t.status,
       l.account_id, l.entry_type, l.amount AS ledger_amount
FROM quickpay.transfers t
JOIN quickpay.ledger_entries l ON l.transfer_id = t.transfer_id
WHERE t.reference LIKE 'P3-TXN-%'
ORDER BY t.transfer_id DESC, l.entry_type;


-- ======================================================
-- EXERCISE 8: Failed transfer - automatic ROLLBACK
-- Attempts NGN 999,999,999 (more than the balance).
-- The debit guard fails, the exception aborts the transaction, and NOTHING is written.
-- ======================================================

BEGIN;

DO $$
DECLARE
    v_amount NUMERIC(19,4) := 999999999.00;
BEGIN
    UPDATE quickpay.accounts
    SET balance = balance - v_amount
    WHERE account_id = 1 AND balance >= v_amount;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transfer failed: insufficient funds in account 1';
    END IF;

    UPDATE quickpay.accounts
    SET balance = balance + v_amount
    WHERE account_id = 2;
END $$;
-- [SCREENSHOT 08a-insufficient-funds-error] (error message)

ROLLBACK;  -- the transaction is already aborted; this ends it.

-- Verify [SCREENSHOT 08b-balances-unchanged]
-- Expect: same balances as after Exercise 7.
SELECT account_id, balance FROM quickpay.accounts
WHERE account_id IN (1, 2) ORDER BY account_id;


-- ======================================================
-- EXERCISE 9: LOST UPDATE ANOMALY (two sessions)
-- Both sessions read the balance, compute a new value in the "application", and write it back. Session B's write overwrites Session A's - NGN 100 disappears.
-- Manual Commit mode. Note the starting balance (= X).
-- ======================================================

-- Step 1  [Session A]
BEGIN;
SELECT balance FROM quickpay.accounts WHERE account_id = 1;   -- reads X

-- Step 2  [Session B]
BEGIN;
SELECT balance FROM quickpay.accounts WHERE account_id = 1;   -- also reads X

-- Step 3  [Session A]  withdraw 100: write X - 100 (replace X with the value read)
UPDATE quickpay.accounts SET balance = /* X */ 0 - 100 WHERE account_id = 1;
COMMIT;

-- Step 4  [Session B]  withdraw 200 from the STALE value: write X - 200
UPDATE quickpay.accounts SET balance = /* X */ 0 - 200 WHERE account_id = 1;
COMMIT;

-- Step 5  [Either]  [SCREENSHOT 09-lost-update]
-- Expect X - 200, NOT X - 300: Session A's withdrawal was lost.
SELECT balance FROM quickpay.accounts WHERE account_id = 1;

-- Step 6  Restore: set the balance back to X.
UPDATE quickpay.accounts SET balance = /* X */ 0 WHERE account_id = 1;
COMMIT;


-- ======================================================
-- EXERCISE 10: LOST UPDATE PREVENTED with FOR UPDATE
-- Same scenario, but each session locks the row when
-- reading AND updates relative to the current value.
-- ======================================================

-- Step 1  [Session A]
BEGIN;
SELECT balance FROM quickpay.accounts WHERE account_id = 1 FOR UPDATE;

-- Step 2  [Session B]  -> BLOCKS (waiting for A's lock)  [SCREENSHOT 10a-waiting]
BEGIN;
SELECT balance FROM quickpay.accounts WHERE account_id = 1 FOR UPDATE;

-- Step 3  [Session A]
UPDATE quickpay.accounts SET balance = balance - 100 WHERE account_id = 1;
COMMIT;
-- Session B now unblocks and reads X - 100 (the NEW value).

-- Step 4  [Session B]
UPDATE quickpay.accounts SET balance = balance - 200 WHERE account_id = 1;
COMMIT;

-- Step 5  [SCREENSHOT 10b-no-lost-update]
-- Expect X - 300: both withdrawals applied.
SELECT balance FROM quickpay.accounts WHERE account_id = 1;

-- Step 6  Restore
UPDATE quickpay.accounts SET balance = balance + 300 WHERE account_id = 1;
COMMIT;


-- ======================================================
-- EXERCISE 11: DEADLOCK (two sessions)
-- A locks account 1 then wants 2; B locks 2 then wants 1.
-- PostgreSQL detects the cycle (~1 s) and aborts one.
-- ======================================================

-- Step 1  [Session A]
BEGIN;
UPDATE quickpay.accounts SET balance = balance - 10 WHERE account_id = 1;

-- Step 2  [Session B]
BEGIN;
UPDATE quickpay.accounts SET balance = balance - 10 WHERE account_id = 2;

-- Step 3  [Session A]  -> blocks, waiting for B
UPDATE quickpay.accounts SET balance = balance + 10 WHERE account_id = 2;

-- Step 4  [Session B]  -> creates the cycle
UPDATE quickpay.accounts SET balance = balance + 10 WHERE account_id = 1;
-- One session gets: ERROR: deadlock detected  [SCREENSHOT 11-deadlock-detected]

-- Step 5  [Both sessions]  clean up - nothing is kept
ROLLBACK;

-- Prevention: always lock accounts in a consistent order
-- (lowest account_id first), as Exercise 7 does.


-- ======================================================
-- EXERCISE 12: SERIALIZATION FAILURE (REPEATABLE READ)
-- PostgreSQL refuses to let a REPEATABLE READ transaction
-- overwrite a row changed by another committed transaction.
-- ======================================================

-- Step 1  [Session A]
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM quickpay.accounts WHERE account_id = 1;   -- snapshot taken

-- Step 2  [Session B]  (autocommit or BEGIN/COMMIT)
BEGIN;
UPDATE quickpay.accounts SET balance = balance - 50 WHERE account_id = 1;
COMMIT;

-- Step 3  [Session A]  still sees the OLD balance (snapshot)
SELECT balance FROM quickpay.accounts WHERE account_id = 1;

-- Step 4  [Session A]
UPDATE quickpay.accounts SET balance = balance - 50 WHERE account_id = 1;
-- ERROR: could not serialize access due to concurrent update
-- [SCREENSHOT 12-serialization-failure]
ROLLBACK;

-- Step 5  Restore Session B's change
UPDATE quickpay.accounts SET balance = balance + 50 WHERE account_id = 1;
COMMIT;


-- ======================================================
-- FINAL CHECK [SCREENSHOT 13-final-balances]
-- Balances should equal the post-Exercise-7 values.
-- ======================================================
SELECT account_id, balance FROM quickpay.accounts
WHERE account_id IN (1, 2) ORDER BY account_id;
