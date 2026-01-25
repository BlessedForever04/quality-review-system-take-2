import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config({ path: './.env' });

const templateSchema = new mongoose.Schema(
  {
    name: { type: String, default: "Default Quality Review Template" },
    defectCategories: { type: [Object], default: [] },
    modifiedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  {
    timestamps: true,
    strict: false,
  },
);

const Template = mongoose.model("Template", templateSchema);

async function checkTemplate() {
  try {
    await mongoose.connect(process.env.MONGO_DB_URI);
    console.log("MongoDB connected");

    let template = await Template.findOne();
    if (!template) {
      console.log("Creating new template...");
      template = await Template.create({ name: "Test Template" });
      console.log("✅ Template created");
    }
    
    console.log("✅ Template found");
    console.log("Raw _doc:", JSON.stringify(template._doc, null, 2));
    console.log("\ntoObject():", JSON.stringify(template.toObject(), null, 2));
    console.log("\nDirect keys:", Object.keys(template._doc || {}));
      
    // Test adding a stage directly using Mongoose markModified
    console.log("\n\n🧪 TEST 1: Using Mongoose markModified + save()...");
    template.stage1 = [];
    template.markModified('stage1');
    
    if (!template.stageNames) {
      template.stageNames = {};
    }
    template.stageNames['stage1'] = 'Test Direct Phase';
    template.markModified('stageNames');
    
    await template.save();
    console.log("✅ Mongoose save() completed");
    
    let refetched = await Template.findOne();
    let hasStage1 = 'stage1' in refetched.toObject();
    console.log(`${hasStage1 ? '✅' : '❌'} stage1 persisted with Mongoose: ${hasStage1}`);
    
    // Now test using MongoDB native updateOne
    console.log("\n\n🧪 TEST 2: Using MongoDB native updateOne()...");
    const updateResult = await Template.collection.updateOne(
      { _id: template._id },
      { $set: { stage2: [], "stageNames.stage2": "Native Update Phase" } }
    );
    console.log("✅ MongoDB updateOne() completed");
    console.log(`   matchedCount: ${updateResult.matchedCount}`);
    console.log(`   modifiedCount: ${updateResult.modifiedCount}`);
    
    refetched = await Template.findOne();
    let hasStage2 = 'stage2' in refetched.toObject();
    console.log(`${hasStage2 ? '✅' : '❌'} stage2 persisted with MongoDB updateOne: ${hasStage2}`);
    
    // Check both
    console.log("\n\n📊 FINAL RESULT:");
    console.log("Full template:", JSON.stringify(refetched.toObject(), null, 2));

    await mongoose.disconnect();
    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exit(1);
  }
}

checkTemplate();
