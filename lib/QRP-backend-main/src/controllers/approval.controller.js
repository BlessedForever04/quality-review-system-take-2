import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ChecklistAnswer from "../models/checklistAnswer.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import Stage from "../models/stage.models.js";
import Project from "../models/project.models.js";

// Utility to compute match between executor and reviewer maps
function answersMatch(execAns, revAns) {
  const keys = new Set([...Object.keys(execAns), ...Object.keys(revAns)]);
  for (const k of keys) {
    const e = execAns[k] || {};
    const r = revAns[k] || {};
    // Only compare answers; ignore remark text
    if ((e.answer || null) !== (r.answer || null)) return false;
  }
  return true;
}

// GET compare status
const compareAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");

  const [exec, rev] = await Promise.all([
    ChecklistAnswer.find({
      project_id: projectId,
      phase: phaseNum,
      role: "executor",
    }),
    ChecklistAnswer.find({
      project_id: projectId,
      phase: phaseNum,
      role: "reviewer",
    }),
  ]);

  const execMap = {};
  exec.forEach((a) => (execMap[a.sub_question] = { answer: a.answer }));
  const revMap = {};
  rev.forEach((a) => (revMap[a.sub_question] = { answer: a.answer }));

  const match = answersMatch(execMap, revMap);
  const stats = { exec_count: exec.length, rev_count: rev.length };
  return res
    .status(200)
    .json(new ApiResponse(200, { match, stats }, "Comparison complete"));
});

// POST request approval (creates/updates approval record to pending)
const requestApproval = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, notes } = req.body;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");

  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: { status: "pending", requested_at: new Date(), notes: notes || "" },
    },
    { new: true, upsert: true }
  );
  return res
    .status(200)
    .json(new ApiResponse(200, record, "Approval requested"));
});

// POST approve: SDH decides approved -> advance to next phase (create next stage if needed)
const approve = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.body;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");

  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: {
        status: "approved",
        decided_at: new Date(),
        decided_by: req.user?._id || null,
      },
    },
    { new: true, upsert: true }
  );

  // If phase 3 is approved, mark project as completed
  if (phaseNum === 3) {
    await Project.findByIdAndUpdate(projectId, {
      status: "completed",
    });
    return res
      .status(200)
      .json(
        new ApiResponse(200, record, "Phase 3 approved - Project finished")
      );
  }

  // Advance: create/find next stage Phase (phase+1) but do not copy answers (new values for next phase)
  const nextPhaseName = `Phase ${phaseNum + 1}`;
  const existing = await Stage.findOne({
    project_id: projectId,
    stage_name: nextPhaseName,
  });
  if (!existing) {
    await Stage.create({
      project_id: projectId,
      stage_name: nextPhaseName,
      description: `Auto-created after approval of Phase ${phaseNum}`,
      status: "pending",
      created_by: req.user?._id || null,
    });
  }

  return res
    .status(200)
    .json(new ApiResponse(200, record, "Approved and advanced"));
});

// POST revert: keep current stage
const revert = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, notes } = req.body;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");

  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: {
        status: "reverted",
        decided_at: new Date(),
        decided_by: req.user?._id || null,
        notes: notes || "",
      },
    },
    { new: true, upsert: true }
  );

  // Clear submission state for executor and reviewer so they can edit again
  await ChecklistAnswer.updateMany(
    { project_id: projectId, phase: phaseNum },
    { $set: { is_submitted: false } }
  );

  return res
    .status(200)
    .json(new ApiResponse(200, record, "Reverted to current stage"));
});

// GET approval status
const getApprovalStatus = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");

  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });
  // Return null instead of throwing error - approval record may not exist yet
  if (!record)
    return res
      .status(200)
      .json(new ApiResponse(200, null, "No approval record found"));

  return res
    .status(200)
    .json(new ApiResponse(200, record, "Approval status fetched"));
});

// GET revert count for a specific phase
const getRevertCount = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) throw new ApiError(400, "Invalid phase");

  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });

  const revertCount = record?.revertCount || 0;
  return res
    .status(200)
    .json(new ApiResponse(200, { revertCount }, "Revert count fetched"));
});

// POST increment revert count for a specific phase
const incrementRevertCount = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.body;
  if (!mongoose.isValidObjectId(projectId))
    throw new ApiError(400, "Invalid projectId");
  if (!phase || isNaN(phase) || phase < 1)
    throw new ApiError(400, "Invalid phase");

  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: parseInt(phase) },
    { $inc: { revertCount: 1 } },
    { new: true, upsert: true }
  );

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { revertCount: record.revertCount },
        "Revert count incremented"
      )
    );
});

export { compareAnswers, requestApproval, approve, revert, getApprovalStatus, getRevertCount, incrementRevertCount };
