# MIT 8103 Advanced Database Systems Portfolio

**Student:** Aladi Adaorah · **Matric No.:** 2026/A/MIT/0591301923627 · **Session:** 2026/2027, First Semester · **Case study:** QuickPay Fintech Platform

## Selected Organisation

**QuickPay** is a made-up Nigerian digital payments company. Customers hold Naira (NGN) accounts and send money through a mobile app, a website, USSD (phone-code menus), and API channels.

- **What kind of system it is:** an online system that handles many small money transfers. Every transfer must happen as a single all-or-nothing step (atomic), keep the data correct (consistent), and leave a record that can be checked later (auditable). The system must also keep working as the number of transfers grows (scalability).
- **Who uses the database:** customers (through the apps), the payments service, customer support, the finance team (who check that the books add up), the fraud and compliance team, and the database administrators.
- **What data is stored:** customers, accounts, transfers, double-entry ledger entries, and audit logs in PostgreSQL. Transaction events, a balance cache, and a map of money moving between accounts (a graph) in MongoDB.
- **What the system does:** register customers and open accounts, move money in one all-or-nothing step, reject failed transfers and undo any partial changes, produce statements and volume reports, keep an audit trail, trace suspicious money movement, and archive old transfer data or split it up to handle growth.

The full description is in [`docs/case-study.md`](docs/case-study.md). All data is fictional.

## Portfolio Overview

| #   | Activity                          | Main results                                                                                                                                                                   | Folder                                                                          |
| --- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| 1   | Database Design and Modelling     | A 5-table schema in third normal form (3NF), an ER diagram, rules to keep data valid (primary key, foreign key, UNIQUE, and CHECK), and a double-entry ledger                  | [`portfolio-1-database-design`](portfolio-1-database-design/)                   |
| 2   | Query Processing and Optimisation | Tested query plans with `EXPLAIN ANALYZE` on 200,000 rows. Partial and multi-column indexes cut one query from 960 ms to 0.08 ms. One unused index was found                   | [`portfolio-2-query-optimisation`](portfolio-2-query-optimisation/)             |
| 3   | Transactions and Concurrency      | A transfer that completes fully or not at all, automatic undo on failure, a lost update and how to prevent it, a deadlock, and a serialization failure                         | [`portfolio-3-transactions-concurrency`](portfolio-3-transactions-concurrency/) |
| 4   | NoSQL and Advanced Data Models    | MongoDB document, key-value (entries that expire automatically), and graph (`$graphLookup`) models, plus data validation rules and indexing                                    | [`portfolio-4-nosql`](portfolio-4-nosql/)                                       |
| 5   | Distributed and Cloud Database    | Deployment on Render cloud, splitting a table by date range (queries skip irrelevant data and run 119× faster), and a simulation of spreading data across servers with hashing | [`portfolio-5-distributed-cloud`](portfolio-5-distributed-cloud/)               |

## Documentation

| Document                                                       | What it contains                                                      |
| -------------------------------------------------------------- | --------------------------------------------------------------------- |
| [`docs/case-study.md`](docs/case-study.md)                     | The company, its users, its data, and what the system does            |
| [`docs/final-report.md`](docs/final-report.md)                 | A 2–3 page summary of all five portfolios (for submission on the LMS) |
| [`docs/technical-reflection.md`](docs/technical-reflection.md) | My personal reflection, references, and AI-use declaration            |

## Tools Used

PostgreSQL (hosted on Render) · DBeaver · MongoDB Atlas · Node.js (`mongodb`, `dotenv`) · TablePlus · Mermaid · Visual Studio Code

## How to Run This Project Yourself

1. **PostgreSQL:** run `portfolio-1-database-design/schema.sql`, then `seed.sql`.
2. **Optimisation:** run `portfolio-2-query-optimisation/bulk-data.sql`, then run `optimisation-tests.sql` one step at a time.
3. **Transactions:** follow `portfolio-3-transactions-concurrency/concurrency-tests.sql` using two DBeaver sessions, both in Manual Commit mode.
4. **MongoDB:** in the `portfolio-4-nosql/` folder, run `npm install`, create a `.env` file containing `MONGODB_URI`, then run `npm run basic` and `npm run advanced`.
5. **Partitioning:** run `portfolio-5-distributed-cloud/partitioning.sql` one step at a time.

Each portfolio folder has its own README with detailed steps, results, and screenshots. Passwords and connection details are kept in `.env` files, which `.gitignore` keeps out of the repository.
