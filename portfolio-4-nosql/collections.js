require("dotenv").config();

const { MongoClient } = require("mongodb");

const uri = process.env.MONGODB_URI;
const client = new MongoClient(uri);

async function main() {
  try {
    await client.connect();

    const db = client.db("quickpay_nosql");
    const events = db.collection("transaction_events");

    // 1. Count all transaction events
    const totalEvents = await events.countDocuments();
    console.log("Total transaction events:", totalEvents);

    // 2. Find all completed transfers
    const completedTransfers = await events
      .find({ status: "completed" })
      .toArray();

    console.log("\nCompleted transfers:");
    console.log(completedTransfers);

    // 3. Find failed transfers
    const failedTransfers = await events.find({ status: "failed" }).toArray();

    console.log("\nFailed transfers:");
    console.log(failedTransfers);

    // 4. Find transfers above ₦10,000
    const largeTransfers = await events
      .find({ amount: { $gt: 10000 } })
      .toArray();

    console.log("\nTransfers above ₦10,000:");
    console.log(largeTransfers);

    // 5. Find events from the mobile app
    const mobileAppEvents = await events
      .find({ "metadata.channel": "mobile_app" })
      .toArray();

    console.log("\nMobile app events:");
    console.log(mobileAppEvents);

    // 6. Group transactions by status
    const statusSummary = await events
      .aggregate([
        {
          $group: {
            _id: "$status",
            count: { $sum: 1 },
            totalAmount: { $sum: "$amount" },
          },
        },
        { $sort: { _id: 1 } },
      ])
      .toArray();

    console.log("\nTransaction summary by status:");
    console.log(statusSummary);
  } catch (error) {
    console.error("MongoDB operation failed:", error.message);
    process.exitCode = 1;
  } finally {
    await client.close();
  }
}

main();
