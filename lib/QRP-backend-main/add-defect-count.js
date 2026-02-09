/**
 * Migration script to add defectCount field to existing ProjectChecklist groups
 * Run with: node add-defect-count.js
 */

import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

const MONGODB_URI =
  process.env.MONGO_DB_URI || "mongodb://localhost:27017/quality-review";
const DB_NAME = process.env.DB_NAME || "authdb";

// Connect to MongoDB
await mongoose.connect(MONGODB_URI, { dbName: DB_NAME });
console.log("✓ Connected to MongoDB");
console.log(`✓ Using database: ${DB_NAME}\n`);

const db = mongoose.connection.db;
const collection = db.collection("projectchecklists");

// Function to calculate defect count for a group (any mismatch between executor and reviewer)
function calculateDefectCount(group) {
  let defectCount = 0;

  // Count defects in direct questions (any mismatch between executor and reviewer)
  for (const question of group.questions || []) {
    if (
      question.executorAnswer &&
      question.reviewerAnswer &&
      question.executorAnswer !== question.reviewerAnswer
    ) {
      defectCount++;
    }
  }

  // Count defects in section questions (any mismatch between executor and reviewer)
  for (const section of group.sections || []) {
    for (const question of section.questions || []) {
      if (
        question.executorAnswer &&
        question.reviewerAnswer &&
        question.executorAnswer !== question.reviewerAnswer
      ) {
        defectCount++;
      }
    }
  }

  return defectCount;
}

// Find all ProjectChecklist documents
const checklists = await collection.find({}).toArray();
console.log(`Found ${checklists.length} checklist documents\n`);

let updated = 0;
let alreadyHad = 0;
let totalGroupsUpdated = 0;

for (const checklist of checklists) {
  let needsUpdate = false;
  let groupsUpdatedCount = 0;

  // Process each group
  for (const group of checklist.groups || []) {
    if (group.defectCount === undefined || group.defectCount === null) {
      // Calculate and add defectCount
      group.defectCount = calculateDefectCount(group);
      needsUpdate = true;
      groupsUpdatedCount++;
    } else {
      alreadyHad++;
    }
  }

  // Update document if needed
  if (needsUpdate) {
    const result = await collection.updateOne(
      { _id: checklist._id },
      { $set: { groups: checklist.groups } },
    );
    updated++;
    totalGroupsUpdated += groupsUpdatedCount;
    console.log(
      `✓ Updated checklist ${checklist._id}: ${groupsUpdatedCount} groups updated`,
    );
  }
}

console.log("\n=== Migration Complete ===");
console.log(`Documents updated: ${updated}`);
console.log(`Total groups updated: ${totalGroupsUpdated}`);
console.log(`Groups already had defectCount: ${alreadyHad}`);

// Show a sample document to verify
if (checklists.length > 0) {
  console.log("\n=== Sample Document (first checklist) ===");
  const sample = await collection.findOne({});
  if (sample && sample.groups && sample.groups.length > 0) {
    console.log("First group structure:");
    console.log(JSON.stringify(sample.groups[0], null, 2));
  }
}

await mongoose.disconnect();
console.log("\n✓ Disconnected from MongoDB");
