# Portfolio 4: NoSQL and Advanced Data Models

## 1. Introduction

This portfolio extends the QuickPay fintech case study developed in Portfolio 1. The PostgreSQL database stores structured customer, account, transfer, ledger, and audit information. For this activity, MongoDB is used to model transaction events as flexible, document-oriented records.

The MongoDB database is named `quickpay_nosql`, and its collection is named `transaction_events`.

## 2. NoSQL Data Model

MongoDB stores data as BSON documents, a binary representation of JSON-like data. Each transaction event is represented as an individual document containing its event identifier, event type, transfer reference, source and destination account details, amount, currency, status, timestamp, and metadata.

The model uses nested documents for source and destination accounts. The `metadata` field stores additional information, such as the transaction channel and description. Failed transactions can include a failure reason without requiring every other document to contain that field.

The sample dataset contains three transaction events with different statuses: completed, failed, and pending. These records are illustrative coursework data, not actual financial transactions.

## 3. Implementation

The model was implemented using MongoDB Atlas and TablePlus. The `transaction-events.json` file contains the sample event documents, which were imported into the `transaction_events` collection in the `quickpay_nosql` database.

The `collections.js` file uses the MongoDB Node.js driver to connect to the database and execute queries. The implementation demonstrates:

- Counting documents in the collection.
- Retrieving completed and failed transaction events.
- Filtering transactions by amount.
- Querying nested fields to find events originating from the mobile application.
- Aggregating transaction counts and total amounts by status.

The queries returned the expected results for the three sample documents. Screenshots of the query output, imported documents, and database structure are stored in the `screenshots` directory.

## 4. Suitability of MongoDB for QuickPay

MongoDB is suitable for transaction-event data because its document model supports nested objects and flexible fields. Different event types may contain different metadata, making it possible to store additional event-specific information without requiring every document to follow an identical structure.

The document model also supports filtering and aggregation, which can help QuickPay investigate transaction outcomes, examine activity by channel, and produce summaries of transaction events.

For a production financial system, appropriate validation, access control, monitoring, backup, and data-integrity mechanisms would still be necessary. MongoDB's flexibility does not remove the need for reliable financial controls.

## 5. Comparison with PostgreSQL

PostgreSQL and MongoDB serve complementary purposes in this case study.

PostgreSQL is appropriate for structured customer and account records, relational constraints, foreign keys, and ledger operations that require strong transactional consistency. MongoDB is useful for transaction-event documents containing nested and potentially variable metadata.

The MongoDB implementation does not replace the PostgreSQL database. Instead, it demonstrates how a document-oriented data model can complement a relational system. In a real deployment, the relationship between the operational database and event records would need a reliable event-delivery and reconciliation mechanism.

## 6. Limitations

The implementation uses a small sample dataset, so it demonstrates query functionality rather than production-scale performance. The sample records do not establish a complete financial transaction-processing system. Additional testing would be required to assess performance, access controls, resilience, and consistency between event records and the authoritative financial ledger.

## 7. Conclusion

This portfolio demonstrates a working MongoDB document model for QuickPay transaction events. The imported sample documents and successful JavaScript queries show how MongoDB can store nested event data and support filtering and aggregation. The exercise also illustrates why a document database can complement PostgreSQL within a fintech architecture.
