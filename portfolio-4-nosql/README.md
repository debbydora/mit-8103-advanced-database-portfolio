# Portfolio 4: NoSQL and Advanced Data Models

## Case Study

This portfolio extends the QuickPay fintech database developed in the earlier portfolio activities. It demonstrates how MongoDB can store transaction-event documents alongside a relational PostgreSQL database.

## Objectives

- Implement a document-oriented NoSQL data model.
- Store and query transaction-event documents in MongoDB.
- Use filtering and aggregation to analyse transaction events.
- Explain why MongoDB is suitable for event data and how it complements PostgreSQL.

## Technologies Used

- MongoDB Atlas
- TablePlus
- Node.js
- MongoDB Node.js driver
- dotenv

## Database Structure

- **Database:** `quickpay_nosql`
- **Collection:** `transaction_events`
- **Sample data:** `transaction-events.json`

The collection contains three illustrative transaction-event documents representing completed, failed, and pending transactions.

## Project Files

| File or folder            | Purpose                                                                            |
| ------------------------- | ---------------------------------------------------------------------------------- |
| `collections.js`          | Connects to MongoDB and runs example queries and aggregations.                     |
| `transaction-events.json` | Contains the sample transaction-event documents.                                   |
| `nosql-analysis.md`       | Explains the data model, suitability, comparison with PostgreSQL, and limitations. |
| `screenshots/`            | Contains evidence of query results, imported documents, and database structure.    |
| `package.json`            | Defines the Node.js project and dependencies.                                      |
| `package-lock.json`       | Records dependency versions.                                                       |
| `.gitignore`              | Excludes environment secrets and unnecessary local files.                          |
| `.env`                    | Stores the MongoDB connection string locally and must not be committed.            |

## Setup and Execution

1. Install Node.js and npm.
2. Install the project dependencies using `npm install`.
3. Create a `.env` file containing the MongoDB Atlas connection string:

   `MONGODB_URI="your-mongodb-connection-string"`

4. Ensure the Atlas database user has the required database permissions and that the network access configuration permits the connection.
5. Import `transaction-events.json` into the `transaction_events` collection in the `quickpay_nosql` database if the sample documents have not already been imported.
6. Run the queries:

   `node collections.js`

The script should connect to MongoDB and display the results of its configured queries. The database connection string must remain private.

## Suitability and Design Rationale

MongoDB supports nested documents and flexible fields, which are useful for transaction events with varying metadata. Its query and aggregation features support filtering events by status, amount, and channel, and summarising events by status.

PostgreSQL remains appropriate for QuickPay's authoritative relational records, financial ledger, foreign-key constraints, and transactional balance updates. MongoDB complements that database by providing a document-oriented model for transaction-event information.

## Testing and Evidence

The implementation was tested against the sample documents imported into MongoDB Atlas. Screenshots in the `screenshots/` folder show the query output, collection documents, and database structure.

The sample dataset is illustrative and does not represent real customer or financial data.

## Limitations

The implementation uses a small dataset and is intended to demonstrate NoSQL modelling and querying rather than production-scale performance. Production use would require further testing of access controls, resilience, event delivery, data retention, and reconciliation with the authoritative financial ledger.
