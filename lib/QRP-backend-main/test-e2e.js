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

async function testE2E() {
  try {
    await mongoose.connect(process.env.MONGO_DB_URI);
    console.log("✅ MongoDB connected\n");

    // STEP 1: Create a template
    console.log("📝 STEP 1: Creating template...");
    const template = await Template.create({ 
      name: "E2E Test Template",
      defectCategories: []
    });
    console.log(`✅ Template created with ID: ${template._id}\n`);

    // STEP 2: Add stages using MongoDB updateOne (like the backend controller does)
    console.log("📝 STEP 2: Adding multiple stages...");
    
    const stageUpdates = [
      { stage: "stage1", name: "Requirements & Planning" },
      { stage: "stage2", name: "Design & Architecture" },
      { stage: "stage3", name: "Development & Testing" },
    ];

    for (const { stage, name } of stageUpdates) {
      const updateObj = {
        [stage]: [],
        [`stageNames.${stage}`]: name,
      };
      
      const result = await Template.collection.updateOne(
        { _id: template._id },
        { $set: updateObj }
      );
      
      console.log(`  ✅ Added ${stage} "${name}" (modified: ${result.modifiedCount})`);
    }
    console.log();

    // STEP 3: Fetch and verify all stages are persisted
    console.log("📝 STEP 3: Fetching template and verifying stages...");
    const fetched = await Template.findOne({ _id: template._id });
    const templateObj = fetched.toObject();
    
    const stageKeys = Object.keys(templateObj).filter((key) => /^stage\d+$/.test(key));
    console.log(`✅ Fetched template`);
    console.log(`   Stages found: ${stageKeys.join(", ")}`);
    console.log(`   Stage names: ${JSON.stringify(templateObj.stageNames)}\n`);

    // STEP 4: Verify data integrity
    console.log("📝 STEP 4: Verifying data integrity...");
    let allGood = true;
    
    for (const { stage, name } of stageUpdates) {
      const hasStage = stage in templateObj;
      const hasCustomName = templateObj.stageNames?.[stage] === name;
      
      if (!hasStage) {
        console.log(`  ❌ ${stage} NOT FOUND`);
        allGood = false;
      } else if (!hasCustomName) {
        console.log(`  ⚠️  ${stage} found but custom name incorrect`);
        allGood = false;
      } else {
        console.log(`  ✅ ${stage} "${name}" - verified!`);
      }
    }
    
    if (allGood) {
      console.log("\n🎉 SUCCESS! All stages persisted and retrieved correctly!");
    } else {
      console.log("\n❌ FAILURE! Some stages are missing or incorrect!");
    }

    console.log("\n📊 Final template document:");
    console.log(JSON.stringify(templateObj, null, 2));

    await mongoose.disconnect();
    process.exit(allGood ? 0 : 1);
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exit(1);
  }
}

testE2E();
