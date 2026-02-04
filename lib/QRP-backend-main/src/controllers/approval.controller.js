import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import Stage from "../models/stage.models.js";
import Project from "../models/project.models.js";

// Utility to compute match between executor and reviewer maps
function answersMatch(execAns, revAns) {
  // Only compare questions where BOTH executor and reviewer have provided answers
  const execKeys = Object.keys(execAns);
  const revKeys = Object.keys(revAns);
  
  // Find common questions (where both have answered)
  const commonKeys = execKeys.filter(k => revKeys.includes(k));
  
  // If no common answered questions, they don't differ (reviewer hasn't started yet)
  if (commonKeys.length === 0) return true;
  
  // Compare only the common answered questions
  for (const k of commonKeys) {
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

  // Find the stage for this phase
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    return res
      .status(200)
      .json(new ApiResponse(200, { match: true, stats: { exec_count: 0, rev_count: 0 } }, "No stage found"));
  }

  // Get project checklist for this stage
  const checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    return res
      .status(200)
      .json(new ApiResponse(200, { match: true, stats: { exec_count: 0, rev_count: 0 } }, "No checklist found"));
  }

  // Extract all questions from groups and sections
  const execMap = {};
  const revMap = {};
  let execCount = 0;
  let revCount = 0;

  checklist.groups.forEach(group => {
    // Direct questions in group
    group.questions.forEach(q => {
      const key = q.text;
      if (q.executorAnswer !== null && q.executorAnswer !== undefined) {
        execMap[key] = { answer: q.executorAnswer };
        execCount++;
      }
      if (q.reviewerAnswer !== null && q.reviewerAnswer !== undefined) {
        revMap[key] = { answer: q.reviewerAnswer };
        revCount++;
      }
    });
    
    // Questions in sections
    group.sections.forEach(section => {
      section.questions.forEach(q => {
        const key = q.text;
        if (q.executorAnswer !== null && q.executorAnswer !== undefined) {
          execMap[key] = { answer: q.executorAnswer };
          execCount++;
        }
        if (q.reviewerAnswer !== null && q.reviewerAnswer !== undefined) {
          revMap[key] = { answer: q.reviewerAnswer };
          revCount++;
        }
      });
    });
  });

  const match = answersMatch(execMap, revMap);
  const stats = { exec_count: execCount, rev_count: revCount };
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
    { new: true, upsert: true },
  );
  return res
    .status(200)
    .json(new ApiResponse(200, record, "Approval requested"));
});

// POST approve: TeamLeader decides approved -> advance to next phase (create next stage if needed)
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
    { new: true, upsert: true },
  );

  // Find current stage and mark it as completed
  const currentStageKey = `stage${phaseNum}`;
  await Stage.findOneAndUpdate(
    { project_id: projectId, stage_key: currentStageKey },
    { $set: { status: "completed" } },
  );

  // Find next stage and activate it
  const nextPhaseNum = phaseNum + 1;
  const nextStageKey = `stage${nextPhaseNum}`;
  const nextStage = await Stage.findOne({
    project_id: projectId,
    stage_key: nextStageKey,
  });

  if (nextStage) {
    // Activate the existing next stage
    await Stage.findByIdAndUpdate(nextStage._id, {
      $set: { status: "in_progress" },
    });
    console.log(`✅ Approved phase ${phaseNum}, activated ${nextStageKey}`);
  } else {
    // No more stages - mark project as completed
    await Project.findByIdAndUpdate(projectId, {
      status: "completed",
    });
    console.log(
      `✅ Approved phase ${phaseNum} - Project completed (no more stages)`,
    );
  }

  return res
    .status(200)
    .json(new ApiResponse(200, record, "Approved and advanced to next phase"));
});

// POST revert: DEPRECATED - TeamLeader no longer has revert privileges
// This endpoint is kept for backward compatibility but should not be used
const revert = asyncHandler(async (req, res) => {
  throw new ApiError(403, "TeamLeader revert is no longer supported. Only Reviewer can revert to Executor.");
});

// POST revert to executor: reviewer sends phase back to executor
// This allows the executor to re-fill the checklist if the reviewer is not satisfied
// The cycle can continue until the reviewer approves
const revertToExecutor = asyncHandler(async (req, res) => {
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
        status: "reverted_to_executor",
        decided_at: new Date(),
        decided_by: req.user?._id || null,
        notes: notes || "",
        executor_submitted: false, // Reset submission flag so executor can resubmit
        executor_submitted_at: null,
      },
    },
    { new: true, upsert: true },
  );

  // Clear submission state ONLY for executor so they can edit again
  // Reviewer keeps their submission and can review again after executor resubmits
  // Note: Submission state is now tracked in ChecklistApproval, not in individual answers
  // ProjectChecklist stores the actual answer data

  // Increment conflict counter on the stage to track revision cycles
  const stageKey = `stage${phaseNum}`;
  console.log(
    `🔍 Looking for stage: project_id=${projectId}, stage_key=${stageKey}`,
  );

  const stage = await Stage.findOneAndUpdate(
    { project_id: projectId, stage_key: stageKey },
    { $inc: { conflict_count: 1 } },
    { new: true, upsert: false },
  );

  if (!stage) {
    console.warn(
      `⚠️ Stage not found for project ${projectId}, stage ${stageKey}`,
    );
  }

  const conflictCount = stage?.conflict_count || 0;
  console.log(
    `🔄 Reviewer reverted phase ${phaseNum} to executor, conflict count: ${conflictCount}, stage found: ${!!stage}`,
  );

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { ...record.toObject(), conflict_count: conflictCount },
        "Reverted to Executor - Executor can edit again",
      ),
    );
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
    { new: true, upsert: true },
  );

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { revertCount: record.revertCount },
        "Revert count incremented",
      ),
    );
});

export {
  compareAnswers,
  requestApproval,
  approve,
  revert,
  revertToExecutor,
  getApprovalStatus,
  getRevertCount,
  incrementRevertCount,
};
