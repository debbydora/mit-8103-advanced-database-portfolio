# QuickPay Fintech Database — Portfolio 1

## Project Overview

This project presents the database design and modelling for a simulated fintech platform called QuickPay. The database is implemented in PostgreSQL and organised under the `quickpay` schema.

QuickPay is designed to manage customer information, financial accounts, account-to-account transfers, ledger entries, and audit logs. The project demonstrates relational database design, entity relationships, primary and foreign keys, integrity constraints, normalisation, and SQL-based verification.

All data used in this project is fictional and intended for academic purposes.

## Portfolio 1 Objectives

The objectives of this portfolio are to:

- Describe the selected fintech case study.
- Identify the database entities, attributes, and relationships.
- Define the relational schema and its keys.
- Implement constraints that support data integrity.
- Explain the application of First, Second, and Third Normal Forms.
- Implement and verify the database using PostgreSQL.

## Database Tables

The database contains five principal tables:

| Table            | Purpose                                                          |
| ---------------- | ---------------------------------------------------------------- |
| `customers`      | Stores customer identity and contact information.                |
| `accounts`       | Stores customer accounts, account types, balances, and statuses. |
| `transfers`      | Records transfers between source and destination accounts.       |
| `ledger_entries` | Records debit and credit entries associated with transfers.      |
| `audit_logs`     | Records important system and customer-related activities.        |

## Project Files

| File or folder    | Description                                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------------------------ |
| `schema.sql`      | Creates the database schema, tables, constraints, and indexes.                                                     |
| `seed.sql`        | Inserts fictional sample data into the tables.                                                                     |
| `queries.sql`     | Contains queries for inspecting records, validating relationships, checking constraints, and generating summaries. |
| `design-notes.md` | Documents the case study, relational schema, relationships, keys, constraints, normalisation, and limitations.     |
| `er-diagram.mmd`  | Contains the Mermaid source code for the entity-relationship diagram.                                              |
| `er-diagram.png`  | Provides an exported visual representation of the ER diagram.                                                      |
| `screenshots/`    | Contains screenshots of database execution and verification results.                                               |

## Technologies and Tools

- PostgreSQL
- SQL
- DBeaver
- Visual Studio Code
- Mermaid for the ER diagram

## Setup and Execution

The scripts are intended to be executed against the PostgreSQL database configured for this project.

1. Connect to the correct PostgreSQL database in DBeaver.
2. Open `schema.sql` and execute it to create the `quickpay` schema, tables, constraints, and indexes.
3. Open `seed.sql` and execute it to insert the sample data.
4. Open `queries.sql` and execute the verification and reporting queries.
5. Review the result grids and confirm that the tables contain the expected records and that the integrity checks identify no unexpected issues.
6. Review the ER diagram and design documentation.

The `schema.sql` script uses `CREATE TABLE IF NOT EXISTS`, so changes to an existing table definition may require a deliberate migration or a controlled recreation of the affected objects.

## Database Integrity

The database uses primary keys, foreign keys, unique constraints, check constraints, default values, and indexes to support data integrity and common query operations.

Verification queries check record counts, duplicate values, account ownership, transfer references, ledger relationships, audit-log references, and the consistency of ledger entries for successful transfers.

## Scope and Limitations

This project demonstrates database design and implementation for an academic fintech case study. It does not implement a complete production-grade payment-processing system.

Features such as atomic transfer execution, concurrent balance updates, idempotency, reversal processing, and automated ledger reconciliation would require additional transactional logic.

## Academic Integrity and AI Assistance

Any AI assistance used in preparing or reviewing this project should be disclosed in accordance with the course instructions. The submitted work should be reviewed, tested, and understood by the student.

## Portfolio Evidence

The accompanying design documentation, ER diagram, SQL scripts, and screenshots provide evidence of the database design, implementation, and verification for Portfolio 1.
