# Portfolio 3: Transactions and Concurrency

## 1. Overview

This portfolio demonstrates transaction management and concurrency control in the QuickPay PostgreSQL database. Using real account data, it shows:

- **Atomicity:** a funds transfer that updates balances, the transfer record, and the double-entry ledger as one unit.
- **COMMIT and ROLLBACK:** including automatic rollback when a business rule fails.
- **Isolation:** `READ COMMITTED` and `REPEATABLE READ` behaviour across two sessions.
- **A concurrency anomaly:** the lost update, and how row locking prevents it.
- **Deadlock detection** and the lock-ordering strategy that prevents it.
- **Serialization failure** under `REPEATABLE READ`.

## 2. Environment and Method

| Item          | Detail                                                                           |
| ------------- | -------------------------------------------------------------------------------- |
| Database      | PostgreSQL (`quickpay` schema)                                                   |
| Client        | DBeaver, two SQL editors with **separate connections** (Session A and Session B) |
| Commit mode   | Manual Commit for two-session tests                                              |
| Accounts used | Account 1 (`SP1000000001`) and account 2 (`SP1000000002`), both active, NGN      |

Two-session tests were run one statement at a time, alternating between the sessions in the documented order. Every test restored the balances afterwards, and the final check confirmed account 1 = ₦149,000.00 and account 2 = ₦276,000.00 (the values after the single committed transfer in Exercise 7).

## 3. Project Files

| File                    | Purpose                                                                                                                          |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `transactions.sql`      | Exercises 1–6: basic transfer logic, ROLLBACK, transaction-scoped settings, row locking, COMMIT, and `READ COMMITTED` isolation. |
| `concurrency-tests.sql` | Exercises 7–12: full atomic transfer, automatic rollback, lost update, `FOR UPDATE`, deadlock, and serialization failure.        |
| `screenshots/`          | Evidence for every exercise (listed in Section 6).                                                                               |

## 4. Part 1: Basic Transaction Behaviour (Exercises 1–6)

| #   | Exercise                                         | Result                                                                                        |
| --- | ------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| 1   | Atomic transfer logic (guarded debit and credit) | Superseded by the full transfer in Exercise 7.                                                |
| 2   | ROLLBACK of a ₦500 deduction                     | Balance returned to ₦150,000.00.                                                              |
| 3   | Transaction-scoped setting (`SET LOCAL`)         | Reverted after ROLLBACK.                                                                      |
| 4   | Row lock with `SELECT ... FOR UPDATE`            | Session B's update waited until Session A released the lock.                                  |
| 5   | COMMIT of a session setting                      | Setting persisted after COMMIT.                                                               |
| 6   | `READ COMMITTED` isolation                       | Session B saw ₦150,000.00 while Session A held an uncommitted ₦150,001.00; **no dirty read**. |

## 5. Part 2: Atomic Transfers and Concurrency Control (Exercises 7–12)

### Exercise 7: Full Atomic Transfer (COMMIT)

A ₦1,000 transfer from account 1 to account 2 was executed as one transaction containing five writes: debit, credit, a `transfers` row, and two `ledger_entries` rows (debit and credit). The transaction first locks both account rows **in ascending `account_id` order** to prevent deadlocks, and each update is guarded (active status, matching currency, sufficient funds).

| Account | Before      | After       |
| ------- | ----------- | ----------- |
| 1       | ₦150,000.00 | ₦149,000.00 |
| 2       | ₦275,000.00 | ₦276,000.00 |

The ledger query returned exactly one `debit` (account 1) and one `credit` (account 2) of ₦1,000 for the new transfer, so the double-entry ledger balances. Total money across both accounts was unchanged (₦425,000), demonstrating **atomicity and consistency**.

### Exercise 8: Failed Transfer (automatic ROLLBACK)

A transfer of ₦999,999,999 was attempted. The guarded debit matched no rows, so the block raised:

```
ERROR: Transfer failed: insufficient funds in account 1
```

PostgreSQL aborted the transaction, and `ROLLBACK` ended it. Balances remained ₦149,000.00 and ₦276,000.00: **no partial transfer was written**. This shows how an error inside a transaction guarantees all-or-nothing behaviour.

### Exercise 9: Lost Update Anomaly

Both sessions read account 1's balance (₦149,000) under the default `READ COMMITTED` level, then each wrote back a value computed by the "application":

| Step | Session A                        | Session B                                                 |
| ---- | -------------------------------- | --------------------------------------------------------- |
| 1    | `BEGIN`; reads ₦149,000          |                                                           |
| 2    |                                  | `BEGIN`; reads ₦149,000                                   |
| 3    | Writes ₦148,900 (−100); `COMMIT` |                                                           |
| 4    |                                  | Writes ₦148,800 (−200, from its **stale** read); `COMMIT` |
| 5    | Reads **₦148,800**               |                                                           |

The correct balance is ₦148,700. **Session A's ₦100 withdrawal was lost**, because Session B overwrote it using an outdated value. `READ COMMITTED` prevents dirty reads, but it does **not** prevent this read-modify-write race.

### Exercise 10: Lost Update Prevented with `SELECT ... FOR UPDATE`

The same scenario was repeated, with each session locking the row when reading and updating relative to the current value (`balance = balance - n`).

| Step | Session A                                                | Session B                                               |
| ---- | -------------------------------------------------------- | ------------------------------------------------------- |
| 1    | `BEGIN`; `SELECT ... FOR UPDATE` → ₦149,000 (row locked) |                                                         |
| 2    |                                                          | `BEGIN`; `SELECT ... FOR UPDATE` → **blocked, waiting** |
| 3    | `balance - 100`; `COMMIT` (lock released)                | unblocks, reads **₦148,900**                            |
| 4    |                                                          | `balance - 200`; `COMMIT`                               |
| 5    | Final balance **₦148,700**                               |                                                         |

Both withdrawals were applied. The row lock **serialised** the two read-modify-write operations, so Session B worked from the current value instead of a stale one. This is **pessimistic concurrency control**.

### Exercise 11: Deadlock Detection

| Step | Session A                                 | Session B                                   |
| ---- | ----------------------------------------- | ------------------------------------------- |
| 1    | `BEGIN`; updates account **1** (locks it) |                                             |
| 2    |                                           | `BEGIN`; updates account **2** (locks it)   |
| 3    | updates account 2 → waits for B           |                                             |
| 4    |                                           | updates account 1 → waits for A (**cycle**) |

After about 1 second (`deadlock_timeout`), PostgreSQL detected the wait cycle and aborted **Session B** with `ERROR: deadlock detected`, allowing Session A's statement to complete. Both sessions were then rolled back, leaving balances unchanged.

**Prevention:** all transfers should acquire account locks in a consistent order. Exercise 7 does this with `ORDER BY account_id ... FOR UPDATE`, so two concurrent transfers between the same accounts (in either direction) always lock the lower-numbered account first and cannot deadlock. Applications should also retry transactions that are aborted by deadlock detection.

### Exercise 12: Serialization Failure under `REPEATABLE READ`

| Step | Session A (`REPEATABLE READ`)                                                   | Session B                                          |
| ---- | ------------------------------------------------------------------------------- | -------------------------------------------------- |
| 1    | reads ₦149,000 (snapshot taken)                                                 |                                                    |
| 2    |                                                                                 | `balance - 50`; `COMMIT` (actual balance ₦148,950) |
| 3    | reads again → **still ₦149,000** (snapshot)                                     |                                                    |
| 4    | `balance - 50` → **ERROR: could not serialize access due to concurrent update** |                                                    |

Under `REPEATABLE READ`, Session A works from a consistent snapshot, so it cannot see B's committed change (**no non-repeatable read**). When A attempted to update a row that had changed since its snapshot, PostgreSQL refused rather than silently overwrite B's work. This is **optimistic concurrency control**: conflicts are detected at write time, and the application must retry the transaction.

## 6. Evidence

| Screenshot                                                                                     | Shows                                                                 |
| ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `01-rollback-test.png`                                                                         | Balance restored after ROLLBACK (Ex. 2)                               |
| `02-transaction-rollback.png`                                                                  | Transaction-local setting reverted (Ex. 3)                            |
| `03a-row-lock-waiting.png`, `03b-row-lock-released.png`                                        | Row lock wait and release (Ex. 4)                                     |
| `04-commit-test.png`                                                                           | Setting persisted after COMMIT (Ex. 5)                                |
| `05a-isolation-session-a.png`, `05b-isolation-session-b.png`                                   | `READ COMMITTED`: no dirty read (Ex. 6)                               |
| `06-baseline-balances.png`                                                                     | Starting balances ₦150,000 / ₦275,000                                 |
| `07-transfer-notice.png`, `07a-atomic-transfer-balances.png`, `07b-atomic-transfer-ledger.png` | Committed transfer, new balances, and balanced ledger entries (Ex. 7) |
| `08a-insufficient-funds-error.png`, `08b-balances-unchanged.png`                               | Automatic rollback on failure (Ex. 8)                                 |
| `09-lost-update.png`                                                                           | Lost update: ₦148,800 instead of ₦148,700 (Ex. 9)                     |
| `10a-waiting.png`, `10b-no-lost-update.png`                                                    | Session B blocked by `FOR UPDATE`; correct ₦148,700 (Ex. 10)          |
| `11-deadlock-detected.png`                                                                     | `deadlock detected` error in Session B (Ex. 11)                       |
| `12a-snapshot-read.png`, `12b-serialization-failure.png`                                       | Snapshot read and serialization failure (Ex. 12)                      |
| `13-final-balances.png`                                                                        | Final balances ₦149,000 / ₦276,000                                    |

## 7. Summary of Concepts Demonstrated

| ACID property / concept | Demonstrated by                                                                |
| ----------------------- | ------------------------------------------------------------------------------ |
| Atomicity               | Ex. 7 (all five writes committed together), Ex. 8 (nothing written on failure) |
| Consistency             | Guards and CHECK constraints; balanced ledger; total funds preserved           |
| Isolation               | Ex. 6 (`READ COMMITTED`), Ex. 12 (`REPEATABLE READ` snapshot)                  |
| Durability              | Committed transfer persisted and was visible from other sessions               |
| Concurrency anomaly     | Ex. 9 (lost update)                                                            |
| Pessimistic control     | Ex. 4 and Ex. 10 (`SELECT ... FOR UPDATE`)                                     |
| Optimistic control      | Ex. 12 (serialization failure, retry required)                                 |
| Deadlock handling       | Ex. 11 (detection) and Ex. 7 (lock ordering for prevention)                    |

## 8. Conclusion and Recommendations for QuickPay

The exercises show that transactions alone do not guarantee correct results under concurrency: the default `READ COMMITTED` level allowed a lost update. For QuickPay's transfer service, the recommended approach is:

1. Execute every transfer as **one transaction** covering balances, the transfer record, and ledger entries.
2. **Lock both accounts with `SELECT ... FOR UPDATE` in ascending `account_id` order** before checking balances, preventing lost updates and deadlocks.
3. Update balances **relative to the current value** (`balance = balance - amount`) with guard conditions, never by writing a value computed from an earlier read.
4. **Retry** transactions that fail with deadlock or serialization errors.
5. Consider `SERIALIZABLE` for complex multi-row rules, accepting a higher retry rate.

## 9. Limitations

Tests were run manually on two accounts with a small number of sessions. They demonstrate correctness behaviour rather than throughput under load. Production use would also require idempotency keys for repeated requests, automated retry logic, and monitoring of lock waits and deadlocks.
