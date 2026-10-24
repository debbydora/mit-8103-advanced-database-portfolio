/*
=========================================================
QUICKPAY - PORTFOLIO 4 (PART 2): ADVANCED NOSQL MODELLING

Run:  node advanced.js     (or: npm run advanced)

Sections:
  1. Normalise the original sample timestamps (string -> Date)
  2. Generate 2,000 realistic, polymorphic transaction events
  3. Schema validation with $jsonSchema (+ rejected-insert test)
  4. Indexing: explain() BEFORE vs AFTER a compound index
  5. Analytical aggregation pipelines
  6. Key-value model: account balance cache with TTL index
  7. Graph model: money-flow tracing with $graphLookup

=========================================================
*/

require("dotenv").config();
const { MongoClient } = require("mongodb");

const client = new MongoClient(process.env.MONGODB_URI);

// ---------- helpers ----------
const line = (title) =>
  console.log(`\n${"=".repeat(60)}\n${title}\n${"=".repeat(60)}`);

// Deterministic pseudo-random generator so every run produces the same data.
let seed = 42;
const rand = () => {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  return seed / 2147483648;
};
const pick = (arr) => arr[Math.floor(rand() * arr.length)];

// Summarise an explain() result: winning plan stage + work done.
function summariseExplain(exp) {
  const stats = exp.executionStats;
  const stages = [];
  let node = exp.queryPlanner.winningPlan;
  while (node) {
    stages.push(node.stage + (node.indexName ? `(${node.indexName})` : ""));
    node = node.inputStage;
  }
  return {
    plan: stages.join(" <- "),
    docsExamined: stats.totalDocsExamined,
    keysExamined: stats.totalKeysExamined,
    returned: stats.nReturned,
    timeMs: stats.executionTimeMillis,
  };
}

async function main() {
  await client.connect();
  const db = client.db("quickpay_nosql");
  const events = db.collection("transaction_events");

  // ======================================================
  // 1. NORMALISE ORIGINAL SAMPLE TIMESTAMPS
  // The imported JSON stored timestamps as strings. Dates
  // must be BSON Date to support range queries and sorting.
  // ======================================================
  line("1. Normalise timestamps (string -> Date)");
  const fix = await events.updateMany({ timestamp: { $type: "string" } }, [
    { $set: { timestamp: { $toDate: "$timestamp" } } },
  ]);
  console.log("Documents converted:", fix.modifiedCount);

  // ======================================================
  // 2. GENERATE POLYMORPHIC EVENTS
  // Different event types carry different fields - the key
  // reason a document model suits event data.
  // ======================================================
  line("2. Generate 2,000 transaction events");

  // Remove validator temporarily so re-runs can clean up freely.
  await db.command({ collMod: "transaction_events", validator: {} });
  const removed = await events.deleteMany({ event_id: /^GEN-/ });
  console.log("Previous generated events removed:", removed.deletedCount);

  const accounts = Array.from({ length: 10 }, (_, i) => ({
    account_id: i + 1,
    account_number: `SP10000000${String(i + 1).padStart(2, "0")}`,
  }));
  const channels = ["mobile_app", "web", "ussd", "api"];
  const failureReasons = [
    "insufficient_funds",
    "account_frozen",
    "limit_exceeded",
    "suspected_fraud",
    "network_timeout",
  ];
  const devices = ["iOS", "Android"];
  const start = new Date("2026-07-01T00:00:00Z").getTime();
  const span = 90 * 24 * 60 * 60 * 1000; // 90 days

  const docs = [];
  for (let i = 1; i <= 2000; i++) {
    const src = pick(accounts);
    let dst = pick(accounts);
    while (dst.account_id === src.account_id) dst = pick(accounts);

    const r = rand();
    const status =
      r < 0.8
        ? "completed"
        : r < 0.92
          ? "failed"
          : r < 0.97
            ? "pending"
            : "reversed";
    const channel = pick(channels);

    const metadata = { channel, description: "Generated transfer event" };
    // Polymorphic, type-specific fields:
    if (channel === "mobile_app") {
      metadata.device = {
        os: pick(devices),
        app_version: `3.${Math.floor(rand() * 5)}.0`,
      };
    }
    if (channel === "ussd") metadata.ussd_code = "*737#";
    if (channel === "api")
      metadata.api_client = pick(["merchant-pos", "payroll-svc"]);

    const doc = {
      event_id: `GEN-${String(i).padStart(5, "0")}`,
      event_type: `transfer.${status}`,
      transfer_reference: `QP-GEN-${String(i).padStart(5, "0")}`,
      source_account: src,
      destination_account: dst,
      amount: Math.round((100 + rand() * 249900) * 100) / 100,
      currency: "NGN",
      status,
      timestamp: new Date(start + Math.floor(rand() * span)),
      metadata,
    };
    if (status === "failed") doc.failure_reason = pick(failureReasons);
    if (status === "reversed") {
      doc.reversal = {
        reason: pick(["customer_dispute", "duplicate_transaction"]),
        reversed_at: new Date(doc.timestamp.getTime() + 3600 * 1000),
      };
    }
    docs.push(doc);
  }
  const ins = await events.insertMany(docs);
  console.log("Inserted:", ins.insertedCount);
  console.log("Total documents now:", await events.countDocuments());

  // ======================================================
  // 3. SCHEMA VALIDATION ($jsonSchema)
  // Flexible, but not schemaless: core financial fields are
  // enforced, while metadata may vary by event type.
  // ======================================================
  line("3. Schema validation");

  await db.command({
    collMod: "transaction_events",
    validator: {
      $jsonSchema: {
        bsonType: "object",
        required: [
          "event_id",
          "event_type",
          "source_account",
          "destination_account",
          "amount",
          "currency",
          "status",
          "timestamp",
        ],
        properties: {
          event_id: { bsonType: "string" },
          event_type: { bsonType: "string", pattern: "^transfer\\." },
          amount: {
            bsonType: ["double", "int", "long", "decimal"],
            minimum: 0.01,
          },
          currency: { bsonType: "string", pattern: "^[A-Z]{3}$" },
          status: { enum: ["completed", "failed", "pending", "reversed"] },
          timestamp: { bsonType: "date" },
          source_account: {
            bsonType: "object",
            required: ["account_id", "account_number"],
          },
          destination_account: {
            bsonType: "object",
            required: ["account_id", "account_number"],
          },
          metadata: { bsonType: "object" }, // contents intentionally flexible
        },
      },
    },
    validationLevel: "strict",
    validationAction: "error",
  });
  console.log("Validator applied (strict / error).");

  // Test: an invalid document must be rejected.
  try {
    await events.insertOne({
      event_id: "BAD-0001",
      event_type: "transfer.completed",
      source_account: { account_id: 1, account_number: "SP1000000001" },
      destination_account: { account_id: 2, account_number: "SP1000000002" },
      amount: -500, // invalid: negative
      currency: "naira", // invalid: not ISO-4217
      status: "done", // invalid: not in enum
      timestamp: new Date(),
    });
    console.log("UNEXPECTED: invalid document was accepted");
  } catch (err) {
    console.log("Invalid document rejected as expected:");
    console.log("  code:", err.code, "-", err.message);
  }

  // ======================================================
  // 4. INDEXING: explain() BEFORE vs AFTER
  // Query: latest 20 failed events (fraud/ops dashboard).
  // ======================================================
  line("4. Index optimisation with explain()");

  const idxName = "idx_status_timestamp";
  const existing = await events.indexes();
  if (existing.some((i) => i.name === idxName)) await events.dropIndex(idxName);

  const query = () =>
    events.find({ status: "failed" }).sort({ timestamp: -1 }).limit(20);

  const before = summariseExplain(await query().explain("executionStats"));
  console.log("BEFORE:", before);

  await events.createIndex({ status: 1, timestamp: -1 }, { name: idxName });
  await events.createIndex(
    { event_id: 1 },
    { name: "uq_event_id", unique: true },
  );
  await events.createIndex(
    { "source_account.account_id": 1, timestamp: -1 },
    { name: "idx_source_account_timestamp" },
  );

  const after = summariseExplain(await query().explain("executionStats"));
  console.log("AFTER: ", after);

  console.log("\nIndexes on transaction_events:");
  (await events.indexes()).forEach((i) =>
    console.log(" ", i.name, JSON.stringify(i.key)),
  );

  // ======================================================
  // 5. AGGREGATION PIPELINES
  // ======================================================
  line("5a. Volume and success rate by channel");
  console.table(
    await events
      .aggregate([
        {
          $group: {
            _id: "$metadata.channel",
            events: { $sum: 1 },
            completed: {
              $sum: { $cond: [{ $eq: ["$status", "completed"] }, 1, 0] },
            },
            total_amount: { $sum: "$amount" },
          },
        },
        {
          $project: {
            _id: 0,
            channel: "$_id",
            events: 1,
            success_rate_pct: {
              $round: [
                { $multiply: [{ $divide: ["$completed", "$events"] }, 100] },
                1,
              ],
            },
            total_amount: { $round: ["$total_amount", 2] },
          },
        },
        { $sort: { events: -1 } },
      ])
      .toArray(),
  );

  line("5b. Failure reasons (fraud / operations monitoring)");
  console.table(
    await events
      .aggregate([
        { $match: { status: "failed" } },
        { $group: { _id: "$failure_reason", count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $project: { _id: 0, failure_reason: "$_id", count: 1 } },
      ])
      .toArray(),
  );

  line("5c. Monthly completed volume");
  console.table(
    await events
      .aggregate([
        { $match: { status: "completed" } },
        {
          $group: {
            _id: { $dateToString: { format: "%Y-%m", date: "$timestamp" } },
            transfers: { $sum: 1 },
            volume: { $sum: "$amount" },
          },
        },
        { $sort: { _id: 1 } },
        {
          $project: {
            _id: 0,
            month: "$_id",
            transfers: 1,
            volume: { $round: ["$volume", 2] },
          },
        },
      ])
      .toArray(),
  );

  line("5d. Mobile app events by device OS (nested, optional field)");
  console.table(
    await events
      .aggregate([
        { $match: { "metadata.device.os": { $exists: true } } },
        { $group: { _id: "$metadata.device.os", events: { $sum: 1 } } },
        { $project: { _id: 0, os: "$_id", events: 1 } },
      ])
      .toArray(),
  );

  // ======================================================
  // 6. KEY-VALUE MODEL: balance cache with TTL
  // _id = account number (the key); value = cached balance.
  // A TTL index expires entries automatically, like Redis
  // EXPIRE. PostgreSQL remains the source of truth.
  // ======================================================
  line("6. Key-value model: account balance cache (TTL)");
  const cache = db.collection("account_balance_cache");
  await cache.createIndex(
    { cached_at: 1 },
    { expireAfterSeconds: 300, name: "ttl_5_min" },
  );

  await cache.bulkWrite(
    [
      ["SP1000000001", 149000.0],
      ["SP1000000002", 276000.0],
    ].map(([key, balance]) => ({
      replaceOne: {
        filter: { _id: key },
        replacement: { balance, currency: "NGN", cached_at: new Date() },
        upsert: true,
      },
    })),
  );

  // O(1) lookup by key (uses the built-in _id index).
  const hit = await cache.findOne({ _id: "SP1000000001" });
  console.log("GET SP1000000001 ->", hit);
  const exp = await cache
    .find({ _id: "SP1000000001" })
    .explain("executionStats");
  console.log("Lookup plan:", summariseExplain(exp));

  // ======================================================
  // 7. GRAPH MODEL: money-flow tracing with $graphLookup
  // Accounts are nodes, completed transfers are edges.
  // Traces where money from account 1 can flow within
  // 3 hops - a common anti-money-laundering technique.
  // ======================================================
  line("7. Graph model: money-flow tracing ($graphLookup)");

  const edges = db.collection("transfer_edges");
  await edges.deleteMany({});
  // Build the edge list (unique source->destination pairs) from events.
  await events
    .aggregate([
      { $match: { status: "completed" } },
      {
        $group: {
          _id: {
            from: "$source_account.account_id",
            to: "$destination_account.account_id",
          },
          transfers: { $sum: 1 },
          total: { $sum: "$amount" },
        },
      },
      {
        $project: {
          _id: 0,
          from: "$_id.from",
          to: "$_id.to",
          transfers: 1,
          total: { $round: ["$total", 2] },
        },
      },
      { $out: "transfer_edges" },
    ])
    .toArray();
  await edges.createIndex({ from: 1 }, { name: "idx_from" });
  console.log("Edges (unique account pairs):", await edges.countDocuments());

  const reach = await edges
    .aggregate([
      { $match: { from: 1 } },
      { $limit: 1 },
      {
        $graphLookup: {
          from: "transfer_edges",
          startWith: "$from",
          connectFromField: "to",
          connectToField: "from",
          as: "path",
          maxDepth: 2, // 3 hops in total
          depthField: "hop",
        },
      },
      { $unwind: "$path" },
      {
        $group: {
          _id: "$path.to",
          first_reached_at_hop: { $min: { $add: ["$path.hop", 1] } },
        },
      },
      { $sort: { first_reached_at_hop: 1, _id: 1 } },
      {
        $project: {
          _id: 0,
          reachable_account: "$_id",
          first_reached_at_hop: 1,
        },
      },
    ])
    .toArray();
  console.log("Accounts reachable from account 1 within 3 hops:");
  console.table(reach);

  // Circular flow check: can money leave account 1 and return to it?
  const cycle = reach.find((r) => r.reachable_account === 1);
  console.log(
    cycle
      ? `Circular flow detected: funds can return to account 1 in ${cycle.first_reached_at_hop} hops.`
      : "No circular flow back to account 1 within 3 hops.",
  );
}

main()
  .catch((err) => {
    console.error("MongoDB operation failed:", err.message);
    process.exitCode = 1;
  })
  .finally(() => client.close());
