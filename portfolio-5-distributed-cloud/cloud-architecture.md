# Portfolio 5: QuickPay Cloud Database Architecture

## 1. Overview

QuickPay is a simulated fintech platform that manages customers, accounts, transfers, ledger entries, and audit logs. This portfolio examines how cloud database technologies can support the platform's availability, scalability, and reliability as transaction volume grows.

The existing PostgreSQL database is hosted on Render. The deployment verification tests confirm database connectivity, the presence of the five QuickPay tables, and the availability of their records.

## 2. Proposed Architecture

The proposed architecture consists of the following components:

1. **Application layer:** A QuickPay backend receives requests to retrieve account information and initiate transfers.
2. **Primary PostgreSQL database:** Stores authoritative customer, account, transfer, ledger, and audit records.
3. **Read replica:** A proposed replica receives replicated data from the primary database and serves suitable read-only requests.
4. **Backup and recovery:** Regular backups and tested restoration procedures support recovery after accidental data loss or infrastructure failure.
5. **Monitoring:** Database health, connection failures, query performance, replication lag, and storage usage are monitored.

The read replica, automated failover, and monitoring components are proposed design elements unless separately configured and verified in the deployment.

## 3. Replication

Replication maintains copies of database data on separate database instances. A primary PostgreSQL instance can replicate changes to one or more standby or read-replica instances.

For QuickPay, a replica could support reporting queries and account-history retrieval, reducing some read traffic on the primary database.

However, replication may introduce lag. A replica might not immediately contain a newly committed transfer. Therefore, balance checks and operations requiring the latest authoritative state should use the primary database or an appropriately designed consistency mechanism.

## 4. Sharding

Sharding divides a large dataset across multiple database partitions or nodes. A sharding strategy for QuickPay could distribute selected data by a stable customer identifier or account identifier.

For example, a future large-scale deployment might assign customer records to different partitions based on a defined identifier range or hash.

Sharding adds routing and operational complexity. Transfers involving accounts on different shards require careful transaction coordination. Financial ledger consistency must not be sacrificed for scalability.

The current implementation does not establish a sharded PostgreSQL deployment; sharding is discussed as a potential future scaling strategy.

## 5. Availability and Recovery

Availability means that users can access the service when needed. QuickPay could improve availability through database monitoring, backups, standby instances, documented recovery procedures, and tested failover.

A backup is not the same as a live replica: backups support restoration, while replicas may support read traffic or recovery depending on their configuration.

A production design should define recovery point objectives (RPO) and recovery time objectives (RTO), and test whether its backup and recovery arrangements meet them.

## 6. Consistency

Consistency ensures that database operations preserve defined rules and that users receive data appropriate to the operation.

For financial transactions, PostgreSQL transactions and constraints should protect account and ledger integrity. A transfer should update the relevant records atomically, so a partial transfer is not treated as successful.

Asynchronous replication can mean that a replica temporarily returns stale data. QuickPay should use the primary database for critical balance and transfer decisions unless the system implements a verified alternative consistency strategy.

## 7. Security

The deployment should use encrypted database connections, least-privilege database accounts, protected environment variables, access controls, and secure credential management. Secrets must not be committed to the Git repository or exposed in screenshots.

## 8. Conclusion

A cloud-hosted PostgreSQL database provides a practical foundation for QuickPay. Replication can improve read capacity and support recovery, sharding can support future growth, and backups, monitoring, and tested failover can improve resilience. These benefits depend on actual configuration and testing. The current work verifies cloud database accessibility; additional infrastructure would be required to demonstrate a fully replicated or sharded deployment.
