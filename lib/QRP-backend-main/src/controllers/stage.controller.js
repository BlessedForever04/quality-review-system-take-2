import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Stage from "../models/stage.models.js";
import Project from "../models/project.models.js";
import Template from "../models/template.models.js";
import Checklist from "../models/checklist.models.js";
import Checkpoint from "../models/checkpoint.models.js";
import ProjectChecklist from "../models/projectChecklist.models.js";

const deriveStageKey = (stageName = "") => {
  const lower = stageName.toLowerCase();
  // Match "phase X" or "stage X" where X is 1-99
  const match = lower.match(/(?:phase|stage)\s*(\d{1,2})/);
  if (match) {
    const phaseNum = parseInt(match[1]);
    return `stage${phaseNum}`;
  }
  return null;
};

const mapTemplateGroups = (stageTemplate = []) => {
  return stageTemplate.map((group) => ({
    groupName: (group?.text || "").trim(),
    questions: (group?.checkpoints || []).map((cp) => ({
      text: (cp?.text || "").trim(),
      executorAnswer: null,
      executorRemark: "",
      reviewerStatus: null,
      reviewerRemark: "",
    })),
    sections: (group?.sections || []).map((sec) => ({
      sectionName: (sec?.text || "").trim(),
      questions: (sec?.checkpoints || []).map((cp) => ({
        text: (cp?.text || "").trim(),
        executorAnswer: null,
        executorRemark: "",
        reviewerStatus: null,
        reviewerRemark: "",
      })),
    })),
  }));
};

// Utility: clone template data into a project when stages are missing
const cloneTemplateToProject = async (projectId, userId) => {
  const project = await Project.findById(projectId).populate(
    "created_by",
    "name email",
  );
  if (!project) {
    throw new ApiError(404, "Project not found");
  }

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(
      404,
      "Template not found. Please create a template first.",
    );
  }

  const creatorId = userId || project.created_by?._id;

  // Build stage definitions from template dynamically
  // Get all stage keys (stage1, stage2, etc.) from template
  const stageKeys = Object.keys(template.toObject())
    .filter((key) => /^stage\d{1,2}$/.test(key))
    .sort((a, b) => {
      const numA = parseInt(a.replace("stage", ""));
      const numB = parseInt(b.replace("stage", ""));
      return numA - numB;
    });

  // Build stage definitions using phase names from template
  const phaseNames = template.phaseNames || new Map();
  const stageDefs = stageKeys.map((key) => ({
    name: phaseNames.get ? phaseNames.get(key) : phaseNames[key] || `${key}`,
    key: key,
  }));

  const stageDocs = [];

  for (const def of stageDefs) {
    const stage = await Stage.create({
      project_id: projectId,
      stage_name: def.name,
      stage_key: def.key, // Store the template stage key
      status: "pending",
      created_by: creatorId,
      loopback_count: 0, // Explicitly initialize counter
      conflict_count: 0, // Explicitly initialize counter
    });
    stageDocs.push({ doc: stage, key: def.key });
  }

  for (const { doc: stage, key } of stageDocs) {
    const checklists = template[key] || [];
    for (const cl of checklists) {
      const checklist = await Checklist.create({
        stage_id: stage._id,
        created_by: creatorId,
        checklist_name: cl.text,
        description: "",
        status: "draft",
        revision_number: 0,
        answers: {},
      });

      const cps = cl.checkpoints || [];
      for (const cp of cps) {
        await Checkpoint.create({
          checklistId: checklist._id,
          question: cp.text,
          executorResponse: {},
          reviewerResponse: {},
        });
      }
    }

    const groups = mapTemplateGroups(checklists);
    await ProjectChecklist.findOneAndUpdate(
      { projectId, stageId: stage._id },
      {
        $setOnInsert: {
          projectId,
          stageId: stage._id,
          stage: stage.stage_name,
          groups,
        },
      },
      { upsert: true, new: true },
    );
  }

  // Return only the stage documents to the caller
  return stageDocs.map((entry) => entry.doc);
};

const listStagesForProject = asyncHandler(async (req, res) => {
  const { projectId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  let stages = await Stage.find({ project_id: projectId })
    .sort({ createdAt: 1 })
    .lean(); // Convert to plain JavaScript objects

  console.log(`\n📊 Found ${stages.length} stages for project ${projectId}`);
  console.log("📦 Raw stage data from MongoDB:");
  stages.forEach((s) => {
    console.log(
      `   ${s.stage_key}: loopback_count=${s.loopback_count}, conflict_count=${s.conflict_count}`,
    );
  });

  // Auto-clone template if project has no stages yet (ensures checklists exist)
  if (stages.length === 0) {
    const project = await Project.findById(projectId);

    if (!project) {
      throw new ApiError(404, "Project not found");
    }

    // Clone template into this project when no stages exist (regardless of status)
    stages = await cloneTemplateToProject(projectId, req.user?._id);
    // Convert to lean objects and ensure counters are present
    stages = stages.map((s) => {
      const obj = s.toObject ? s.toObject() : s;
      return {
        ...obj,
        loopback_count: obj.loopback_count || 0,
        conflict_count: obj.conflict_count || 0,
      };
    });
  }

  // Convert to plain objects AFTER potential cloning
  stages = stages.map((stage) => {
    const obj = stage.toObject ? stage.toObject() : stage;
    // Ensure counters exist even if not in DB (backward compatibility)
    obj.loopback_count = obj.loopback_count ?? 0;
    obj.conflict_count = obj.conflict_count ?? 0;
    return obj;
  });

  // Ensure all stages have counter fields (add if missing)
  stages = stages.map((stage) => ({
    ...stage,
    loopback_count:
      stage.loopback_count !== undefined ? stage.loopback_count : 0,
    conflict_count:
      stage.conflict_count !== undefined ? stage.conflict_count : 0,
  }));

  // Log counter values being sent to frontend
  console.log("\n🚀 Sending stages to frontend:");
  stages.forEach((stage) => {
    console.log(
      `   ${stage.stage_key}: loopback=${stage.loopback_count}, conflict=${stage.conflict_count}`,
    );
  });

  // Ensure a project checklist document exists per stage (idempotent)
  try {
    const template = await Template.findOne();
    for (const stage of stages) {
      // Use stage_key if available, otherwise try to derive it from stage name
      let stageKey = stage.stage_key;
      if (!stageKey) {
        stageKey = deriveStageKey(stage.stage_name);
      }
      const stageTemplate = stageKey ? template?.[stageKey] || [] : [];
      const groups = mapTemplateGroups(stageTemplate);
      await ProjectChecklist.findOneAndUpdate(
        { projectId, stageId: stage._id },
        {
          $setOnInsert: {
            projectId,
            stageId: stage._id,
            stage: stage.stage_name,
            groups,
          },
        },
        { upsert: true },
      );
    }
  } catch (e) {
    console.log(
      "Warning: unable to ensure project checklist existence:",
      e.message,
    );
  }

  // Log counters for debugging
  console.log("📊 Stages with counters:");
  stages.forEach((stage, index) => {
    console.log(
      `  Stage ${index + 1}: ${stage.stage_name} (${stage.stage_key}) - loopback: ${stage.loopback_count || 0}, conflict: ${stage.conflict_count || 0}`,
    );
  });

  return res
    .status(200)
    .json(new ApiResponse(200, stages, "Stages fetched successfully"));
});

const getStageById = asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (!mongoose.isValidObjectId(id)) {
    throw new ApiError(400, "Invalid stage id");
  }

  const stage = await Stage.findById(id);
  if (!stage) {
    throw new ApiError(404, "Stage not found");
  }

  return res
    .status(200)
    .json(new ApiResponse(200, stage, "Stage fetched successfully"));
});
const createStage = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { stage_name, stage_key, description, status } = req.body;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  if (!stage_name?.trim()) {
    throw new ApiError(400, "stage_name is required");
  }

  // created_by is required by the model; must be authenticated
  const created_by = req.user?._id;
  if (!created_by) {
    throw new ApiError(401, "Not authenticated");
  }

  const stage = await Stage.create({
    project_id: projectId,
    stage_name,
    stage_key: stage_key || null, // Optional: maps to template stage
    description,
    status, // optional; defaults to 'pending' if not provided
    created_by,
  });

  try {
    const template = await Template.findOne();
    // Use provided stage_key, or try to derive it from stage name as fallback
    let stageKey = stage_key;
    if (!stageKey) {
      stageKey = deriveStageKey(stage_name);
    }
    const groups = stageKey
      ? mapTemplateGroups(template?.[stageKey] || [])
      : [];
    await ProjectChecklist.findOneAndUpdate(
      { projectId, stageId: stage._id },
      {
        $setOnInsert: {
          projectId,
          stageId: stage._id,
          stage: stage.stage_name,
          groups,
        },
      },
      { upsert: true },
    );
  } catch (e) {
    console.log(
      "Warning: unable to create project checklist for new stage:",
      e.message,
    );
  }

  return res
    .status(201)
    .json(new ApiResponse(201, stage, "Stage created successfully"));
});
const updateStage = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { stage_name, description, status } = req.body;

  if (!mongoose.isValidObjectId(id)) {
    throw new ApiError(400, "Invalid stage id");
  }

  // Only allow updating permitted fields
  const update = {};
  if (typeof stage_name === "string") update.stage_name = stage_name;
  if (typeof description === "string") update.description = description;
  if (typeof status === "string") update.status = status;

  if (Object.keys(update).length === 0) {
    throw new ApiError(400, "No valid fields provided to update");
  }

  const stage = await Stage.findByIdAndUpdate(
    id,
    { $set: update },
    { new: true, runValidators: true },
  );

  if (!stage) {
    throw new ApiError(404, "Stage not found");
  }

  return res
    .status(200)
    .json(new ApiResponse(200, stage, "Stage updated successfully"));
});
const deleteStage = asyncHandler(async (req, res) => {
  const { id } = req.params;

  if (!mongoose.isValidObjectId(id)) {
    throw new ApiError(400, "Invalid stage id");
  }

  const deleted = await Stage.findByIdAndDelete(id);
  if (!deleted) {
    throw new ApiError(404, "Stage not found");
  }

  return res
    .status(200)
    .json(new ApiResponse(200, deleted, "Stage deleted successfully"));
});

// Migration helper: Add counter fields to existing stages
const migrateStageCounters = asyncHandler(async (req, res) => {
  try {
    // Update all stages that don't have counter fields
    const result = await Stage.updateMany(
      {
        $or: [
          { loopback_count: { $exists: false } },
          { conflict_count: { $exists: false } },
        ],
      },
      {
        $set: {
          loopback_count: 0,
          conflict_count: 0,
        },
      },
    );

    console.log(
      `✓ Migration complete: ${result.modifiedCount} stages updated with counter fields`,
    );

    return res.status(200).json(
      new ApiResponse(
        200,
        {
          matchedCount: result.matchedCount,
          modifiedCount: result.modifiedCount,
        },
        "Stage counters migration completed",
      ),
    );
  } catch (error) {
    console.error("Migration error:", error);
    throw new ApiError(500, "Migration failed: " + error.message);
  }
});

export {
  listStagesForProject,
  getStageById,
  createStage,
  updateStage,
  deleteStage,
  migrateStageCounters,
};
