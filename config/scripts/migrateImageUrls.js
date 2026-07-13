// backend/scripts/migrateImageUrls.js
//
// ONE-TIME migration: strips the old baked-in "http://<ip>:<port>" prefix
// from image URLs already saved in MongoDB, leaving only the relative path
// (e.g. "/uploads/customers/168xxx.jpg"). Run this ONCE after deploying the
// updated controller so old records also become IP-independent.
//
// Usage:
//   node backend/scripts/migrateImageUrls.js
//
// Make sure your MONGO_URI env var / connection string is set correctly
// before running (check backend/config/db.js or your .env for the exact var name).

const mongoose = require("mongoose");
const Customer = require("../models/Customer");
require("dotenv").config();

// Matches things like: http://192.168.1.70:5000  or  https://myapp.onrender.com
const HOST_PREFIX_REGEX = /^https?:\/\/[^/]+/;

function stripHost(url) {
  if (!url || typeof url !== "string") return url;
  return url.replace(HOST_PREFIX_REGEX, "");
}

function stripHostArray(arr) {
  if (!Array.isArray(arr)) return arr;
  return arr.map(stripHost);
}

async function migrate() {
  const mongoUri = process.env.MONGO_URI || process.env.MONGODB_URI;
  if (!mongoUri) {
    console.error("❌ No MONGO_URI / MONGODB_URI found in environment. Aborting.");
    process.exit(1);
  }

  await mongoose.connect(mongoUri);
  console.log("✅ Connected to MongoDB");

  const customers = await Customer.find({});
  console.log(`📊 Found ${customers.length} customers to check`);

  let updatedCount = 0;

  for (const customer of customers) {
    let changed = false;

    // Top-level mirrored images
    ["goldImages", "diamondImages", "polkiImages"].forEach((field) => {
      const original = customer[field];
      const cleaned = stripHostArray(original);
      if (JSON.stringify(original) !== JSON.stringify(cleaned)) {
        customer[field] = cleaned;
        changed = true;
      }
    });

    // Per-visit images
    if (Array.isArray(customer.visits)) {
      customer.visits.forEach((visit) => {
        ["goldImages", "diamondImages", "polkiImages"].forEach((field) => {
          const original = visit[field];
          const cleaned = stripHostArray(original);
          if (JSON.stringify(original) !== JSON.stringify(cleaned)) {
            visit[field] = cleaned;
            changed = true;
          }
        });
      });
      if (changed) customer.markModified("visits");
    }

    if (changed) {
      await customer.save();
      updatedCount++;
      console.log(`  ✔ Updated customer ${customer._id} (${customer.name})`);
    }
  }

  console.log(`✅ Migration complete. Updated ${updatedCount} of ${customers.length} customers.`);
  await mongoose.disconnect();
  process.exit(0);
}

migrate().catch((err) => {
  console.error("❌ Migration failed:", err);
  process.exit(1);
});