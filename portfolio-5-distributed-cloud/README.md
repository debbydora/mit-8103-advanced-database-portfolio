# Portfolio 5: Distributed and Cloud Database Exercise

## Case Study

This portfolio extends the simulated QuickPay fintech platform developed in the earlier portfolio activities. QuickPay manages customers, accounts, transfers, ledger entries, and audit logs.

## Objectives

- Examine cloud database deployment.
- Verify connectivity to a hosted PostgreSQL database.
- Analyse replication, sharding, availability, and consistency.
- Propose improvements for scaling and database resilience.
- Document implementation evidence and testing results.

## Technologies Used

- PostgreSQL
- Render PostgreSQL hosting
- DBeaver
- SQL

## Project Structure

| File or folder                  | Purpose                                                                                   |
| ------------------------------- | ----------------------------------------------------------------------------------------- |
| `README.md`                     | Portfolio overview and instructions                                                       |
| `deployment-test.sql`           | Read-only checks for database connectivity, schema, version, timestamp, and record counts |
| `cloud-architecture.md`         | Proposed cloud architecture and component responsibilities                                |
| `distributed-cloud-analysis.md` | Analysis of replication, sharding, availability, and consistency                          |
| `screenshots/`                  | Evidence captured during cloud database verification                                      |

## Implementation

The existing QuickPay PostgreSQL database is hosted on Render. DBeaver was used to connect to the database and execute read-only verification queries.

The tests examine the connected database and PostgreSQL version, the active schema, the five expected QuickPay tables, record counts, and session information.

## How to Run the Tests

1. Ensure that the Render PostgreSQL database is available and that you have valid connection credentials.
2. Open the database connection in DBeaver.
3. Open `deployment-test.sql`.
4. Execute the queries against the intended QuickPay database.
5. Verify the query results and compare the table names with the expected schema.
6. Review the screenshots in `screenshots/`.

Do not place passwords or private connection strings in this repository. Keep credentials in a secure location.

## Evidence

The `screenshots/` folder contains evidence of the cloud connection, database details, schema verification, and record counts.

These screenshots demonstrate database accessibility at the time of testing. They do not independently prove that replication, sharding, or automatic failover is configured.

## Distributed Database Analysis

`distributed-cloud-analysis.md` explains the benefits and trade-offs of replication, sharding, availability, and consistency for QuickPay.

`cloud-architecture.md` proposes an architecture that includes a primary database, a potential read replica, backups, monitoring, and recovery procedures.

Replication, sharding, and automatic failover are proposed enhancements unless separately implemented and verified.

## Limitations

This activity verifies access to a cloud-hosted PostgreSQL database and documents potential distributed database improvements. It does not claim to have implemented a replicated or sharded cluster. Further infrastructure configuration and dedicated testing would be necessary to demonstrate those capabilities.

## Conclusion

The portfolio demonstrates cloud database accessibility and evaluates how distributed database techniques could support QuickPay as it grows. The design prioritises financial data integrity while considering scalability, availability, and recovery.
