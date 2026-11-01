# Individual Technical Reflection

## 1. Design Choices

**Why a payments case study.** I chose a payments platform because it makes database problems feel real. A "lost update" isn't just a theory when it means a customer loses ₦100.

**Storing money as exact numbers.** I used `NUMERIC(19,4)` for money instead of floating-point numbers, which can round slightly wrong. Balances need to be exact.

**Recording every transfer twice.** I used a double-entry ledger, so each transfer creates one debit and one credit. This means the books can always be checked and balanced.

**Putting the rules in the database.** I enforced the allowed status values, non-negative balances, and "sender ≠ receiver" directly in the database, not just in the app code. That way, every client that connects follows the same rules.

**Only keeping indexes that helped.** I added indexes only when the execution plan showed they made a difference. When the database never used `idx_transfers_created_at`, I recommended dropping it.

**Using two databases for different jobs.** PostgreSQL remains the main source of truth for money. MongoDB handles event history, caching, and the money-flow graph, where its flexible structure is useful.

## 2. Challenges I Faced

**My test data was too small.** With only 10 transfers, every query just read the whole table, so my first index showed no real improvement. After I generated 200,000 rows, the difference became clear: the query time dropped from 960 ms to 0.08 ms.

**DBeaver broke my script.** My bulk-insert script failed with a "table gen not found" error because DBeaver split the `WITH` clause away from the `INSERT`. I fixed it by rewriting everything as one statement with a subquery.

**PostgreSQL did something I didn't expect.** For the 30-day query, I expected it to read the whole table. Instead, it used a "skip scan" on an existing multi-column index. I had to research this before I could explain the plan properly.

**Testing with two sessions was tricky.** To reproduce the lost update and the deadlock, I needed two separate connections, Manual Commit mode, and the steps in exactly the right order. At one point I re-ran a restore statement by accident and changed the balance, so I learned to reset it to a known fixed value instead.

**"No schema" still needs structure.** The sample data I imported into MongoDB had timestamps stored as text, and the failure reason was in a different field than expected. I only noticed these problems when I ran aggregations. It showed me that even a "schema-less" database needs a plan for how data should look.

**The uneven shard confused me at first.** One shard held 40% of the data, which looked like a mistake. Then I understood that hashing only spreads data evenly when there are lots of different keys.

## 3. What I Learned

1. **Measure instead of guessing.** Execution plans and buffer counts should decide whether an index or design is worth it, not gut feeling. Buffer counts are also more reliable than timings on a shared cloud server.
2. **A transaction alone isn't enough.** Even with `READ COMMITTED`, a lost update still happened. To be safe, you also need row locks, relative updates (like `balance = balance - 100`), a consistent order for locking rows, and retry logic.
3. **Every improvement has a cost.** Indexes slow down writes, sharding makes transactions across accounts harder, and replicas can show out-of-date data.
4. **Try partitioning before sharding.** Splitting the table by date range on a single server made queries 119× faster, without the consistency problems of a distributed setup.
5. **Pick the right tool for each job.** Relational tables suit balances and the ledger. Document, key-value, and graph models suit events, caching, and tracing fraud.

## 4. What I Would Do Next

I would set up a real primary/replica pair so I can measure how far the replica falls behind. I would also move the live `transfers` table to monthly partitions, and build a transactional-outbox pipeline to keep PostgreSQL and MongoDB in sync.

---

## References

- PostgreSQL Global Development Group (2025). _PostgreSQL Documentation_: Using EXPLAIN; Indexes (Partial, Multicolumn); Transaction Isolation; Explicit Locking; Table Partitioning. https://www.postgresql.org/docs/
- MongoDB, Inc. (2025). _MongoDB Manual_: Schema Validation; Indexes and TTL Indexes; Aggregation; `$graphLookup`; `explain()`. https://www.mongodb.com/docs/manual/
- MongoDB, Inc. _MongoDB Node.js Driver Documentation_. https://www.mongodb.com/docs/drivers/node/
- Render. _Render PostgreSQL Documentation_. https://render.com/docs/postgresql
- Elmasri, R. & Navathe, S. B. (2016). _Fundamentals of Database Systems_ (7th ed.). Pearson.
- Kleppmann, M. (2017). _Designing Data-Intensive Applications_. O'Reilly.
- Tools: PostgreSQL, DBeaver, MongoDB Atlas, TablePlus, Node.js, `mongodb` and `dotenv` npm packages, Mermaid, Visual Studio Code.

## AI Use Declaration

| Item                         | Declaration                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **AI tool used**             | GitHub Copilot (chat/agent mode in Visual Studio Code)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **What I used it for**       | Checking my repository against the assessment requirements; drafting SQL scripts (bulk data generation, before/after index tests, concurrency tests, partitioning) and the Node.js MongoDB script; guiding me step by step through running tests in DBeaver; and helping me draft and organise the README and analysis documents from my own test results.                                                                                                                                                                                                                                                       |
| **How I checked the output** | I ran every script myself on my Render PostgreSQL and MongoDB Atlas databases and took the screenshots and outputs. All figures in the documentation come from my own runs. When the generated code failed (for example, the DBeaver "table gen not found" error), I reported the error and confirmed the fix worked. When results didn't match predictions (for example, the skip scan in Test C, the null failure reason, and the uneven shard), I corrected the analysis to match what actually happened. I reviewed and edited the documentation myself, and I can explain every design decision and result. |

I developed the database design (Portfolio 1), the case-study choice, and my earlier portfolio work myself. I take responsibility for the accuracy and originality of this submitted work.
