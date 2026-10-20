# QuickPay Fintech Database: Design Notes

**Portfolio 1** | PostgreSQL | Schema: `quickpay`

---

## 1. Case Study

QuickPay is a simulated fintech platform that manages customers, financial accounts, transfers between accounts, ledger entries and system audit events.

The database supports:

- Customer registration
- Account management
- Transfer tracking
- Financial recordkeeping
- Account ownership validation
- Auditing of important activities

All data is fictional and intended for academic demonstration.

---

## 2. Relational Schema

The database contains five principal relations.

### 2.1 `customers`

Stores customer identity and contact information.

| Item | Detail |
|---|---|
| **Primary key** | `customer_id` |
| **Unique constraint** | Case-insensitive `email`, enforced by a unique index on `LOWER(email)` |
| **Attributes** | `customer_id`, `first_name`, `last_name`, `email`, `phone_number`, `date_of_birth`, `status`, `created_at`, `updated_at` |

**Constraints**

- Names and email are required.
- Names and email cannot be empty or have surrounding whitespace.
- `status` must be `active`, `suspended` or `closed`.

### 2.2 `accounts`

Each account belongs to one customer; a customer may own multiple accounts.

| Item | Detail |
|---|---|
| **Primary key** | `account_id` |
| **Foreign key** | `customer_id` → `customers(customer_id)` |
| **Unique attribute** | `account_number` |
| **Attributes** | `account_id`, `customer_id`, `account_number`, `account_type`, `currency`, `balance`, `status`, `created_at`, `updated_at` |

**Constraints**

- `account_type` must be `savings`, `current` or `wallet`.
- `currency` must be three uppercase letters.
- `balance` cannot be negative.
- `status` must be `active`, `frozen` or `closed`.

### 2.3 `transfers`

Each transfer identifies a sending account, a receiving account and the amount transferred.

| Item | Detail |
|---|---|
| **Primary key** | `transfer_id` |
| **Foreign keys** | `source_account_id` and `destination_account_id`, both → `accounts(account_id)` |
| **Unique attribute** | `reference` |
| **Attributes** | `transfer_id`, `source_account_id`, `destination_account_id`, `amount`, `currency`, `status`, `reference`, `description`, `created_at`, `completed_at` |

**Constraints**

- `amount` must be greater than zero.
- Source and destination accounts must differ.
- `currency` must be three uppercase letters.
- `status` must be `pending`, `processing`, `successful`, `failed` or `reversed`.
- A `successful` transfer must have a completion timestamp.

### 2.4 `ledger_entries`

Records the debit and credit entries associated with transfers.

| Item | Detail |
|---|---|
| **Primary key** | `ledger_entry_id` |
| **Foreign keys** | `transfer_id` → `transfers(transfer_id)`; `account_id` → `accounts(account_id)` |
| **Unique constraint** | `(transfer_id, account_id, entry_type)` |
| **Attributes** | `ledger_entry_id`, `transfer_id`, `account_id`, `entry_type`, `amount`, `currency`, `created_at` |

**Constraints**

- `entry_type` must be `debit` or `credit`.
- `amount` must be greater than zero.
- `currency` must be three uppercase letters.

The uniqueness constraint prevents duplicate entries of the same type for the same account and transfer. It does not guarantee that each successful transfer has the correct matching entries; that requires additional transactional logic.

### 2.5 `audit_logs`

Provides an audit trail of important activities.

| Item | Detail |
|---|---|
| **Primary key** | `audit_log_id` |
| **Foreign key** | `actor_customer_id` → `customers(customer_id)` |
| **Attributes** | `audit_log_id`, `actor_customer_id`, `action`, `entity_type`, `entity_id`, `details`, `created_at` |
| **Referential action** | If the referenced customer is deleted, `actor_customer_id` is set to `NULL` |

**Constraints**

- `action` and `entity_type` cannot be blank.
- `details` must be a JSONB object.

A null actor may represent a system-generated event, or an event whose customer reference was cleared after deletion.

---

## 3. Entity Relationships and Cardinalities

| # | Relationship | Cardinality | Notes |
|---|---|---|---|
| 1 | Customers → Accounts | One-to-many | Each account has one customer; a customer may have several accounts. |
| 2 | Accounts ↔ Transfers | Many-to-many (via two foreign keys) | An account can be the source or destination of many transfers. Each transfer has exactly one source and one destination account. |
| 3 | Transfers → Ledger Entries | One-to-many | The intended pattern for a successful transfer is one debit and one credit. |
| 4 | Accounts → Ledger Entries | One-to-many | Each entry references one account; an account may have many entries. |
| 5 | Customers → Audit Logs | One-to-many | An audit log may also have a null actor. |

---

## 4. Keys and Integrity

- **Primary keys** uniquely identify records in each relation.
- **Foreign keys** maintain referential integrity between related records.
- **Unique constraints** prevent duplicate account numbers and transfer references. The unique index on `LOWER(email)` prevents duplicate emails regardless of letter case.
- **Check constraints** enforce:
  - permitted statuses
  - positive transaction amounts
  - non-negative account balances
  - distinct transfer accounts
  - valid entry types
  - the required currency format
- **Indexes** support common lookups, joins, filtering and chronological retrieval, including customer-account lookups, transfer status and date searches, ledger account history and audit-log searches.

---

## 5. Normalisation

### First Normal Form (1NF)

Each relation has a primary key and stores single values in its attributes, with no repeating groups. For example, customer names and account details are held in separate attributes.

The audit `details` JSONB field is intentionally used for structured event metadata. This does not mean every possible audit detail is modelled as its own relational attribute.

### Second Normal Form (2NF)

All tables use single-column primary keys, so no partial dependencies on part of a composite key can exist. The ledger's composite unique constraint is an additional business rule, not its primary key.

### Third Normal Form (3NF)

The design separates customers, accounts, transfers, ledger entries and audit events into distinct relations.

- Customer details live in `customers` and are not duplicated in accounts or transfers.
- Account ownership is represented by a foreign key.
- Transfers refer to accounts rather than repeating owners' personal details.

This reduces duplication and helps prevent update, insertion and deletion anomalies.

> **Deliberate denormalisation:** `accounts.balance` is a stored value, not one derived automatically from ledger entries. It must be updated consistently with ledger transactions. A production implementation should use atomic database transactions plus validation or reconciliation logic to prevent discrepancies between balances and ledger records.

---

## 6. Implementation and Verification

**Files**

| File | Purpose |
|---|---|
| `schema.sql` | Creates the PostgreSQL schema, tables, constraints and indexes |
| `seed.sql` | Supplies fictional demonstration data |
| `queries.sql` | Inspects records, validates foreign-key relationships, identifies duplicate values, summarises transfers and checks ledger entries for successful transfers |

**Verification checklist**

- [ ] Scripts execute successfully
- [ ] Table and record counts match expectations
- [ ] Joins return valid results
- [ ] Diagnostic queries return no unexpected rows
- [ ] Screenshots of representative query results are captured from DBeaver

---

## 7. Scope and Limitations

This is an academic simulation, not a production-ready banking system. The schema defines structural constraints but does not on its own implement the full transfer-processing workflow. The following require additional transactional logic:

- Atomic balance updates
- Concurrency control
- Idempotent transfer processing
- Reversals
- Comprehensive ledger reconciliation
