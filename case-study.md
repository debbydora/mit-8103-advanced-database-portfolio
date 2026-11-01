# Selected Case Study: QuickPay Fintech Platform

## The Business

**QuickPay** is a made-up Nigerian digital payments company (a fintech). Customers hold Naira (NGN) accounts and send money to each other through a mobile app, a website, USSD (phone-code menus), and an API for other software. QuickPay is not a real company, and all the data in this project is fictional.

## What Kind of System It Is

QuickPay is an online transaction system, which means it handles a large number of small money transfers all day. Getting the money right matters more than anything else. Every transfer must:

- Take money from one account and add it to another as a single all-or-nothing step. Either both happen or neither happens.
- Be recorded in a double-entry ledger (one debit entry and one credit entry per transfer).
- Leave a record that someone can check later.

The platform also needs to:

- Show account balances quickly.
- Produce reports on transaction activity.
- Watch for fraud.
- Keep working as the number of transfers grows.

## Who Uses the Database

| User                                             | What they do                                                                    |
| ------------------------------------------------ | ------------------------------------------------------------------------------- |
| Customers (through the apps)                     | Check balances and history, and send money                                      |
| Transfer service (the software that moves money) | Runs transfers and writes ledger entries                                        |
| Customer support                                 | Look up customers, accounts, and failed transfers                               |
| Finance team                                     | Check that the ledger adds up, and read daily volume reports                    |
| Fraud and compliance team                        | Review failed or suspicious transfers, follow money trails, and read audit logs |
| Database administrators                          | Speed up queries, run backups, split large tables, and deploy changes           |

## What Data Is Stored

| Data                                                                        | Where it is stored                                             | Portfolio |
| --------------------------------------------------------------------------- | -------------------------------------------------------------- | --------- |
| Customers (identity, contact details, status)                               | PostgreSQL table `customers`                                   | 1         |
| Accounts (number, type, currency, balance, status)                          | PostgreSQL table `accounts`                                    | 1         |
| Transfers (sender, receiver, amount, status, reference)                     | PostgreSQL table `transfers` (200,011 rows after load testing) | 1, 2, 5   |
| Double-entry ledger entries                                                 | PostgreSQL table `ledger_entries`                              | 1, 3      |
| Audit logs (details stored as JSONB)                                        | PostgreSQL table `audit_logs`                                  | 1         |
| Transaction events, where the extra details differ from event to event      | MongoDB collection `transaction_events`                        | 4         |
| Cached balances (stored by key, and deleted automatically after a set time) | MongoDB collection `account_balance_cache`                     | 4         |
| Map of money moving between accounts (a graph)                              | MongoDB collection `transfer_edges`                            | 4         |

## Main Things the System Does

- Register customers and open accounts.
- Move money in one all-or-nothing step: debit, credit, transfer record, and ledger entries (Transfer funds atomically)
- Reject failed transfers (for example, not enough money or an inactive account) and undo any partial changes automatically.
- Stop two transfers running at the same time from corrupting a balance, including lost updates and deadlocks.
- Show account statements and recent successful and failed transfers.
- Produce daily and monthly transfer volume reports.
- Keep an audit trail, and trace money that moves in a circle between accounts to detect fraud.
- Archive old transfer data, and handle growth by splitting large tables (partitioning) and spreading data across servers (sharding).
