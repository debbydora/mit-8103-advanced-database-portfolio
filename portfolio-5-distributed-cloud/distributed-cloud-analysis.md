# Portfolio 5: Distributed and Cloud Database Analysis

## 1. Introduction

This activity examines distributed and cloud database concepts using the simulated QuickPay fintech platform. QuickPay stores customer information, account balances, transfers, ledger entries, and audit logs. As the number of users and transactions increases, the platform must consider scalability, availability, data consistency, and recovery from failures.

The practical component uses the PostgreSQL database hosted on Render. SQL tests verify the database connection, PostgreSQL version, schema structure, and records in the five QuickPay tables. These checks establish evidence of cloud deployment and accessibility, but they do not independently prove that replication, sharding, or automatic failover is configured.

## 2. Replication

Replication copies database changes from one database instance to another. In PostgreSQL, a primary instance can send changes to standby instances through mechanisms such as streaming replication.

For QuickPay, a read replica could serve suitable reporting and transaction-history queries while reducing read traffic on the primary database.

Replication has limitations. Asynchronous replicas can lag behind the primary, so recently committed transactions may not immediately appear on a replica. QuickPay should therefore use the authoritative primary for critical balance checks and transfer decisions unless a stronger consistency arrangement has been implemented and verified.

Replication is a proposed enhancement in this portfolio, not a feature claimed to be configured in the current Render deployment.

## 3. Sharding

Sharding partitions data across multiple database nodes. It can help a system distribute storage and workload when a single database instance becomes a bottleneck.

QuickPay could eventually partition selected data using a stable customer or account identifier. A routing mechanism would direct each request to the appropriate partition.

However, sharding complicates joins, reporting, maintenance, and transactions that affect accounts on different partitions. Since financial transfers require reliable coordination between source and destination accounts, any sharding strategy must preserve the correctness of account balances and ledger records.

The current implementation does not include a sharded database. Sharding is evaluated as a future scaling option.

## 4. Availability

Availability is the ability of a system to remain accessible when users need it. Database outages can prevent QuickPay customers from viewing balances or initiating transfers.

Possible improvements include health monitoring, redundant infrastructure, tested backups, standby database instances, and documented failover procedures. Recovery objectives should specify how much data loss is acceptable and how quickly the service should be restored.

A successful connection test demonstrates that the database was accessible at the time of testing. It does not guarantee continuous availability or prove that failover works.

## 5. Consistency

Consistency concerns whether database operations preserve rules and whether reads reflect the required state of the data.

QuickPay must prevent incomplete transfers and inconsistent account and ledger records. PostgreSQL transactions, constraints, and appropriate locking help maintain these guarantees.

A distributed design must also account for replica lag and concurrent requests. A transfer should not be accepted merely because a replica reports an old balance. Critical financial decisions must rely on authoritative data and appropriate transactional controls.

## 6. Deployment Evidence and Testing

The cloud deployment was examined using read-only SQL queries executed through DBeaver against the Render-hosted PostgreSQL database.

The captured evidence covers:

- Database name, connected user, and PostgreSQL version.
- Active schema and server timestamp.
- The five expected tables in the `quickpay` schema.
- Record counts for customers, accounts, transfers, ledger entries, and audit logs.

These results demonstrate that the hosted database was reachable and its expected structures and records could be queried during testing.

The tests do not establish replication status, shard distribution, automated failover, or disaster-recovery performance. Those capabilities would require additional configuration and dedicated tests.

## 7. Comparison of the Concepts

| Concept          | Purpose for QuickPay                                                                 | Current status                                                                               |
| ---------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Cloud deployment | Host and access the PostgreSQL database remotely                                     | Verified using SQL tests                                                                     |
| Replication      | Maintain additional database copies and potentially support read traffic or recovery | Discussed as a proposed enhancement                                                          |
| Sharding         | Distribute selected data and workload across partitions                              | Discussed as a future scaling option                                                         |
| Availability     | Reduce downtime and improve recovery                                                 | Design recommendations documented                                                            |
| Consistency      | Preserve correct account and ledger state                                            | Supported by the existing relational design; distributed consistency considerations analysed |

## 8. Conclusion

Cloud hosting makes the QuickPay database accessible beyond a local development environment. Replication, sharding, and high-availability mechanisms could support future growth, but they require deliberate configuration, monitoring, and testing. For a fintech system, scalability must be balanced with strong transactional integrity and accurate financial records. The implementation evidence and conceptual analysis together demonstrate the distinction between a verified cloud deployment and a proposed distributed architecture.
