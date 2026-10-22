# Portfolio 3: Transactions and Concurrency

## 1. Overview

This portfolio demonstrates transaction management, transaction isolation, and concurrency control in the SwiftPay (QuickPay) PostgreSQL database. The exercises use the `quickpay.accounts` table to explore atomic transaction logic, COMMIT, ROLLBACK, the `READ COMMITTED` isolation level, and row-level locking.

## 2. Exercises Completed

### Exercise 1: Atomic Funds Transfer

A transaction example was prepared to demonstrate updating a source account and a destination account within a single transaction. The example checks account status, currency, and source-account balance before allowing the updates.

**Note:** The transfer script was prepared but not executed against the database.

### Exercise 2: Rollback

A temporary ₦500 deduction was applied to account 1 inside a transaction. The transaction was rolled back, and a subsequent query confirmed that the original balance of ₦150,000.00 was restored.

This demonstrates how `ROLLBACK` cancels uncommitted database changes.

### Exercise 3: Transaction-Scoped Setting

A transaction-local PostgreSQL `application_name` setting was changed within a transaction. After `ROLLBACK`, the transaction-local setting was reverted.

This demonstrated transaction-scoped configuration and rollback behaviour without permanently changing account balances.

### Exercise 4: Row-Level Locking

Session A acquired a row-level lock on account 1 using `SELECT ... FOR UPDATE`. Session B attempted to update the same account and waited while Session A held the lock. After Session A rolled back and released the lock, Session B's update was able to proceed.

The account balance was subsequently restored and verified.

This demonstrates how PostgreSQL coordinates concurrent operations on the same row.

### Exercise 5: COMMIT

A session-level PostgreSQL `application_name` setting was changed within a transaction. After `COMMIT`, a verification query confirmed that the new setting persisted in the session. The setting was then reset.

This demonstrated that `COMMIT` successfully ends a transaction and preserves its committed changes.

### Exercise 6: Transaction Isolation (`READ COMMITTED`)

The isolation test used two separate database sessions.

- **Session A:** Started a transaction and temporarily increased account 1's balance from ₦150,000.00 to ₦150,001.00 without committing the change.
- **Session B:** Queried the same account while Session A's transaction remained open and saw the last committed balance of ₦150,000.00.
- **Rollback:** Session A rolled back the temporary update, restoring the original balance of ₦150,000.00.

**Result:** Session B did not see Session A's uncommitted change. This demonstrated PostgreSQL's `READ COMMITTED` isolation behaviour.

## 3. Evidence

Screenshots are stored in the `screenshots/` folder.

- `01-rollback-test.png` — verifies the account balance after rollback.
- `02-transaction-rollback.png` — shows the transaction-local setting rollback test, if saved.
- `03a-row-lock-waiting.png` — shows Session B waiting for the row lock.
- `03b-row-lock-released.png` — shows Session B proceeding after the lock was released.
- `04-commit-test.png` — verifies the session setting after COMMIT.
- `05a-isolation-session-a.png` — shows Session A's temporary balance.
- `05b-isolation-session-b.png` — shows Session B's committed balance while Session A's transaction was open.

## 4. Conclusion

These exercises demonstrated transaction management, COMMIT, ROLLBACK, the `READ COMMITTED` isolation level, and row-level locking in PostgreSQL. The tests showed how uncommitted changes remain invisible to another session under `READ COMMITTED` and how row locks coordinate concurrent updates.

The account balance was verified as ₦150,000.00 after the temporary changes were rolled back and the concurrency test was completed.

The atomic funds transfer remains an unexecuted example. The tested operations and supporting screenshots document the practical work completed for this portfolio.
