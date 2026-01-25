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

async function testDelete() {
  try {
    await mongoose.connect(process.env.MONGO_DB_URI);
    console.log("✅ MongoDB connected\n");

    // Create a template with stages
    console.log("📝 Creating template with stages...");
    const template = await Template.create({ 
      name: "Delete Test Template",
      defectCategories: []
    });
    
    // Add stages
    await Template.collection.updateOne(
      { _id: template._id },
      { $set: {
        stage1: [],
        stage2: [],
        stage3: [],
        "stageNames.stage1": "Phase 1",
        "stageNames.stage2": "Phase 2",
        "stageNames.stage3": "Phase 3",
      }}
    );
    
    let fetched = await Template.findOne({ _id: template._id });
    const beforeStages = Object.keys(fetched.toObject()).filter((key) => /^stage\d+$/.test(key));
    console.log(`✅ Template created with stages: ${beforeStages.join(", ")}\n`);

    // Test delete using MongoDB updateOne with $unset
    console.log("📝 Deleting stage2...");
    const updateObj = {
      stage2: "",
      "stageNames.stage2": ""
    };
    
    const deleteResult = await Template.collection.updateOne(
      { _id: template._id },
      { $unset: updateObj }
    );
    
    console.log(`✅ Delete completed (modified: ${deleteResult.modifiedCount})`);

    // Verify deletion
    fetched = await Template.findOne({ _id: template._id });
    const afterStages = Object.keys(fetched.toObject()).filter((key) => /^stage\d+$/.test(key));
    const stageNames = Object.keys(fetched.toObject().stageNames || {});
    
    console.log(`\n✅ After deletion:`);
    console.log(`   Remaining stages: ${afterStages.join(", ") || "NONE"}`);
    console.log(`   Remaining stage names: ${stageNames.join(", ") || "NONE"}`);
    
    // Verify stage2 is actually gone
    const hasStage2 = 'stage2' in fetched.toObject();
    const hasStage2Name = 'stage2' in (fetched.toObject().stageNames || {});
    
    if (!hasStage2 && !hasStage2Name) {
      console.log("\n🎉 SUCCESS! stage2 and its name were deleted correctly!");
    } else {
      console.log("\n❌ FAILURE! stage2 or its name still exists!");
      console.log(JSON.stringify(fetched.toObject(), null, 2));
    }

    await mongoose.disconnect();
    process.exit(hasStage2 || hasStage2Name ? 1 : 0);
  } catch (error) {
    console.error("❌ Error:", error.message);
    process.exit(1);
  }
}

testDelete();
