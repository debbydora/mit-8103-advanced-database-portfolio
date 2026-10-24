# Portfolio 4: NoSQL and Advanced Data Models: Analysis

## 1. Introduction

This portfolio extends the QuickPay fintech case study from Portfolios 1–3. PostgreSQL remains the system of record for customers, accounts, transfers, and the double-entry ledger. MongoDB Atlas (database `quickpay_nosql`) is used for workloads that suit non-relational models:

| Collection | Data model | Purpose |
| ---------- | ---------- | ------- |
| `transaction_events` | **Document** | Event log of transfer outcomes with variable, nested metadata |
| `account_balance_cache` | **Key-value** | Fast balance lookups by account number, auto-expiring |
| `transfer_edges` | **Graph** (edge list) | Money-flow tracing between accounts |

The work was carried out in two stages: `collections.js` (basic CRUD-style queries on 3 sample documents) and `advanced.js` (2,000 generated events, validation, indexing, aggregation, key-value, and graph models). Full output is saved in `results/advanced-output.txt`.

## 2. Document Model: `transaction_events`

### 2.1 Design

Each event is a self-contained document: identifiers, embedded `source_account` and `destination_account` sub-documents, amount, currency, status, a BSON `Date` timestamp, and a `metadata` object.

**Embedding vs referencing.** Account number and ID are **embedded** (a snapshot at event time) rather than referenced. Events are immutable history, so the snapshot is the correct value even if the account later changes, and queries need no joins.

**Polymorphism.** Fields vary by event type and channel, which a relational table would model with many nullable columns or extra tables:

| Condition | Extra fields |
| --------- | ------------ |
| `status: failed` | `failure_reason` |
| `status: reversed` | `reversal { reason, reversed_at }` |
| `channel: mobile_app` | `metadata.device { os, app_version }` |
| `channel: ussd` | `metadata.ussd_code` |
| `channel: api` | `metadata.api_client` |

### 2.2 Data Quality Fix

The original 3 imported documents stored `timestamp` as a **string**, which sorts alphabetically and cannot be used in date arithmetic. An update pipeline using `$toDate` converted all 3 to BSON `Date`. This is a typical consequence of schema flexibility: without enforcement, type inconsistencies enter silently.

### 2.3 Schema Validation

A `$jsonSchema` validator (`validationLevel: strict`, `validationAction: error`) now enforces the financial core: required fields, `amount ≥ 0.01`, a three-letter uppercase currency, a `status` enum, a `date` timestamp, and required account sub-fields. `metadata` is deliberately left open.

**Test:** inserting a document with `amount: -500`, `currency: "naira"`, and `status: "done"` was **rejected with error code 121 (Document failed validation)**.

This shows that MongoDB is *schema-flexible*, not *schemaless*: the rules that protect financial correctness are enforced while channel-specific metadata can still evolve.

**Finding: schema drift.** The failure-reason report returned one event with `failure_reason: null`. The cause is that the original sample document stored the reason in `metadata.failure_reason`, while generated events store it at the top level. Validation was added *after* that document was created and does not require the field, so the inconsistency persisted. Remedies are a one-off migration (`$set` / `$unset`) and adding a conditional rule (failed ⇒ `failure_reason` required). This is a real-world lesson: validators should be defined before data is loaded.

### 2.4 Indexing (before vs after)

Query: the latest 20 failed events (`find({status:"failed"}).sort({timestamp:-1}).limit(20)`), typical of a fraud/operations dashboard.

| | Plan | Keys examined | Docs examined | Returned |
| - | ---- | ------------- | ------------- | -------- |
| **Before** | `COLLSCAN → SORT` | 0 | **2,003** | 20 |
| **After** (`{status:1, timestamp:-1}`) | `IXSCAN → FETCH → LIMIT` | 20 | **20** | 20 |

Before the index, MongoDB read every document and sorted the failed ones in memory. After it, MongoDB read exactly 20 index entries and 20 documents, with **no in-memory sort**: a **100× reduction in documents examined**. Both runs reported about 1 ms because the collection is small and cached; as in Portfolio 2, *work done* (documents examined) is the reliable measure, and that difference grows linearly with collection size.

This mirrors the PostgreSQL index `idx_transfers_status_created`, following the same **Equality → Sort** rule for compound key order.

Additional indexes:
- `uq_event_id` (unique): prevents duplicate events, supporting idempotent event ingestion.
- `idx_source_account_timestamp`: supports per-account event history on a nested field.

### 2.5 Aggregation Results

**Channel performance (5a).**

| Channel | Events | Success rate | Volume (₦) |
| ------- | ------ | ------------ | ---------- |
| web | 526 | 80.6% | 65,164,846.03 |
| api | 509 | 79.8% | 62,531,269.71 |
| mobile_app | 499 | 80.6% | 60,434,116.39 |
| ussd | 469 | 81.0% | 55,797,872.22 |

Success rates are uniform (about 80%), as expected from synthetic data generated with one probability. In production, a channel with a markedly lower rate would signal a channel-specific fault.

**Failure reasons (5b).** `suspected_fraud` (46) was the most frequent, followed by `account_frozen` and `network_timeout` (44 each). This grouping supports fraud and operational monitoring.

**Monthly volume (5c).** July 590, August 540, and September 481 completed transfers, plus the 1 original sample event in October. The `$dateToString` grouping only works because of the timestamp conversion in 2.2.

**Device breakdown (5d).** iOS 260, Android 237. The query targets a nested field present only on mobile events (`$exists`), which would require a separate table or nullable columns in SQL.

## 3. Key-Value Model: `account_balance_cache`

The account number is the key (`_id`), and the value is `{balance, currency, cached_at}`. A **TTL index** (`expireAfterSeconds: 300`) automatically deletes entries 5 minutes after caching, similar to Redis `EXPIRE`.

**Result:** `GET SP1000000001` returned `balance: 149000`, matching PostgreSQL after Portfolio 3. The plan was `EXPRESS_IXSCAN(_id_)`: **1 key and 1 document examined, 0 ms**, MongoDB's fast path for exact `_id` lookups.

**Suitability.** Balance enquiries are among the most frequent fintech reads. Serving them from a key-value cache reduces load on the PostgreSQL primary. Because the cache is **eventually consistent**, it must only be used for display. Transfer decisions must read the locked balance from PostgreSQL, as shown in Portfolio 3 (Exercise 10).

## 4. Graph Model: `transfer_edges`

Completed transfers were aggregated into an edge list (`from`, `to`, `transfers`, `total`) with `$out`, producing **90 edges**: every ordered pair of the 10 accounts (10 × 9). `$graphLookup` then traversed edges from account 1 up to 3 hops.

**Result:** all nine other accounts were reachable at hop 1, and **account 1 was reachable again at hop 2**, so the script reported *"Circular flow detected: funds can return to account 1 in 2 hops."*

**Interpretation.** Circular flows (A → B → A, or longer loops) are a recognised money-laundering indicator ("round-tripping"). In SQL, this traversal needs a recursive CTE; in a graph model it is a single traversal stage.

**Limitation.** The synthetic data is **fully connected** (90 of 90 possible edges), so every account reaches every other in one hop and a cycle is guaranteed. Real transaction graphs are sparse, so detected cycles would be meaningful. A production system would also filter edges by time window and amount, and for deep or large-scale traversal a dedicated graph database (e.g. Neo4j) would be more efficient than `$graphLookup`.

## 5. Comparison with PostgreSQL

| Aspect | PostgreSQL (Portfolios 1–3) | MongoDB (Portfolio 4) |
| ------ | --------------------------- | --------------------- |
| Schema | Fixed, enforced by DDL and constraints | Flexible; enforced selectively by `$jsonSchema` |
| Relationships | Foreign keys and joins | Embedding (snapshots); `$lookup`/`$graphLookup` when needed |
| Transactions | Multi-row ACID, row locks, isolation levels | Single-document atomic by default; multi-document transactions available but costlier |
| Indexing | B-tree, partial, composite | Compound, unique, TTL, nested-field |
| Best fit for QuickPay | Balances, transfers, ledger (**source of truth**) | Event history, analytics, caching, relationship tracing |

## 6. Architecture Recommendation (Polyglot Persistence)

1. **PostgreSQL** executes transfers atomically (Portfolio 3) and remains authoritative.
2. After commit, an event is published (ideally via the **transactional outbox pattern**, so an event is never lost or emitted for a rolled-back transfer) and written to `transaction_events`. The unique `event_id` index makes re-delivery idempotent.
3. **Balance cache** entries are refreshed on each committed transfer and expire automatically.
4. **Edges** are rebuilt periodically for fraud analysis.

## 7. Limitations

- Data is synthetic, with 10 accounts and uniform probabilities, so the aggregation figures illustrate capability rather than real behaviour.
- Timings at 2,003 documents are too small to differ. Documents examined is used as the performance measure.
- No replication, sharding, or failover testing was done in MongoDB (see Portfolio 5 for distributed concepts).
- Synchronisation between PostgreSQL and MongoDB is described, not implemented.

## 8. Conclusion

MongoDB complements, rather than replaces, PostgreSQL for QuickPay. The document model handled polymorphic events naturally; schema validation restored control over critical fields; a compound index reduced documents examined from 2,003 to 20; a TTL-indexed key-value collection provided constant-time balance lookups; and `$graphLookup` traced money flows and detected a circular path. The schema-drift and string-timestamp issues showed that flexibility requires deliberate validation to maintain data quality.
