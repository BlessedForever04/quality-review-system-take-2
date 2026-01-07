import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Checkpoint from "../models/checkpoint.models.js";
import Checklist from "../models/checklist.models.js";

/**
 * CREATE CHECKPOINT
 * POST /api/v1/checklists/:checklistId/checkpoints
 * Creates a new checkpoint (question) within a checklist
 */
export const createCheckpoint = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;
  const { question, categoryId } = req.body;

  if (!mongoose.isValidObjectId(checklistId)) {
    throw new ApiError(400, "Invalid checklistId");
  }

  if (!question?.trim()) {
    throw new ApiError(400, "question is required");
  }

  // Verify checklist exists
  const checklist = await Checklist.findById(checklistId);
  if (!checklist) {
    throw new ApiError(404, "Checklist not found");
  }

  // Create checkpoint
  const checkpoint = await Checkpoint.create({
    checklistId: checklistId,
    question: question.trim(),
    categoryId: categoryId || undefined,
    executorResponse: {},
    reviewerResponse: {},
  });

  return res
    .status(201)
    .json(new ApiResponse(201, checkpoint, "Checkpoint created successfully"));
});

/**
 * GET CHECKPOINTS BY CHECKLIST ID
 * GET /api/v1/checklists/:checklistId/checkpoints
 * Fetches all checkpoints for a specific checklist (without image data for performance)
 */
export const getCheckpointsByChecklistId = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;

  if (!mongoose.isValidObjectId(checklistId)) {
    throw new ApiError(400, "Invalid checklist id");
  }

  // Exclude large image buffers from response for performance
  const checkpoints = await Checkpoint.find({ checklistId: checklistId })
    .select("-executorResponse.images.data -reviewerResponse.images.data")
    .sort({ createdAt: 1 });

  return res
    .status(200)
    .json(
      new ApiResponse(200, checkpoints, "Checkpoints fetched successfully")
    );
});

/**
 * GET CHECKPOINT BY ID
 * GET /api/v1/checkpoints/:checkpointId
 * Fetches a single checkpoint by ID (without image data)
 */
export const getCheckpointById = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  const checkpoint = await Checkpoint.findById(checkpointId).select(
    "-executorResponse.images.data -reviewerResponse.images.data"
  );

  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  return res
    .status(200)
    .json(new ApiResponse(200, checkpoint, "Checkpoint fetched successfully"));
});

/**
 * UPDATE CHECKPOINT RESPONSE
 * PATCH /api/v1/checkpoints/:checkpointId
 * Updates executor or reviewer response for a checkpoint
 * Automatically detects defects when answers differ
 * Body: { executorResponse?: {...}, reviewerResponse?: {...}, defectCategoryId?: string }
 */
export const updateCheckpointResponse = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { executorResponse, reviewerResponse, defectCategoryId } = req.body;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  // Update executor response
  if (executorResponse) {
    checkpoint.executorResponse = {
      ...checkpoint.executorResponse,
      ...executorResponse,
      respondedAt: new Date(),
    };
  }

  // Handle executor images from multipart upload (if using multer)
  if (req.files?.length) {
    req.files.forEach((file) => {
      checkpoint.executorResponse.images.push({
        data: file.buffer,
        contentType: file.mimetype,
      });
    });
  }

  // Update reviewer response
  if (reviewerResponse) {
    checkpoint.reviewerResponse = {
      ...checkpoint.reviewerResponse,
      ...reviewerResponse,
      reviewedAt: new Date(),
    };
  }

  // Auto-detect defects: compare executor and reviewer answers
  // Defect = executor answer ≠ reviewer answer
  if (
    checkpoint.executorResponse.answer !== null &&
    checkpoint.reviewerResponse.answer !== null
  ) {
    const answersMatch =
      checkpoint.executorResponse.answer === checkpoint.reviewerResponse.answer;
    const wasDefectDetected = checkpoint.defect.isDetected;
    checkpoint.defect.isDetected = !answersMatch;

    if (!answersMatch) {
      // Defect detected
      checkpoint.defect.detectedAt = new Date();

      // Increment history counter if this is a new defect (wasn't detected before)
      // This ensures defect is counted in history even if later resolved
      if (!wasDefectDetected) {
        checkpoint.defect.historyCount =
          (checkpoint.defect.historyCount || 0) + 1;
      }

      // If defectCategoryId provided, assign it; otherwise keep existing or null
      if (defectCategoryId) {
        checkpoint.defect.categoryId = defectCategoryId;
      }
    } else {
      // No defect (answers match), clear current defect status but keep history
      checkpoint.defect.isDetected = false;
      checkpoint.defect.categoryId = null;
      checkpoint.defect.detectedAt = null;
      // NOTE: historyCount is NOT reset - it persists to track historical defects
    }
  }

  await checkpoint.save();

  return res
    .status(200)
    .json(new ApiResponse(200, checkpoint, "Checkpoint updated successfully"));
});

/**
 * DELETE CHECKPOINT
 * DELETE /api/v1/checkpoints/:checkpointId
 * Deletes a checkpoint by ID
 */
export const deleteCheckpoint = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  await checkpoint.deleteOne();

  return res
    .status(200)
    .json(new ApiResponse(200, null, "Checkpoint deleted successfully"));
});

/**
 * ASSIGN DEFECT CATEGORY
 * PATCH /api/v1/checkpoints/:checkpointId/defect-category
 * Assigns or updates a defect category for a checkpoint
 * Body: { categoryId: string } - category ID from template
 * Body: { categoryId: string, severity?: string } - category ID from template and optional severity
 */
export const assignDefectCategory = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { categoryId, severity } = req.body;

  if (!mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpoint id");
  }

  if (!categoryId || typeof categoryId !== "string" || !categoryId.trim()) {
    throw new ApiError(
      400,
      "categoryId is required and must be a non-empty string"
    );
  }

  // Validate severity if provided
  if (severity && !["Critical", "Non-Critical"].includes(severity)) {
    throw new ApiError(
      400,
      "Invalid severity. Must be 'Critical' or 'Non-Critical'"
    );
  }

  const checkpoint = await Checkpoint.findById(checkpointId);
  if (!checkpoint) {
    throw new ApiError(404, "Checkpoint not found");
  }

  // Mark defect as detected and assign category (allows manual defect assignment by reviewer)
  checkpoint.defect.isDetected = true;
  checkpoint.defect.categoryId = categoryId.trim();
  checkpoint.defect.detectedAt = new Date();

  // Add severity if provided
  if (severity) {
    checkpoint.defect.severity = severity;
  }

  // Increment history count if not already counted
  if (checkpoint.defect.historyCount === 0) {
    checkpoint.defect.historyCount = 1;
  }

  await checkpoint.save();

  return res
    .status(200)
    .json(
      new ApiResponse(200, checkpoint, "Defect category assigned successfully")
    );
});

/**
 * GET DEFECT STATISTICS BY CHECKLIST (Based on History)
 * GET /api/v1/checklists/:checklistId/defect-stats
 * Returns defect statistics based on historical defect count (not current mismatches)
 */
export const getDefectStatsByChecklist = asyncHandler(async (req, res) => {
  const { checklistId } = req.params;

  if (!mongoose.isValidObjectId(checklistId)) {
    throw new ApiError(400, "Invalid checklistId");
  }

  // Get all checkpoints for this checklist to know the questions
  const checkpoints = await Checkpoint.find({ checklistId: checklistId });
  const totalCheckpoints = checkpoints.length;

  // Get the checklist and its stage to find project_id and phase
  const Checklist = require("../models/checklist.models.js").default;
  const checklist = await Checklist.findById(checklistId).populate("stage_id");

  if (!checklist || !checklist.stage_id) {
    throw new ApiError(404, "Checklist or stage not found");
  }

  const stage = checklist.stage_id;
  const projectId = stage.project_id;
  const phase = stage.phase;

  // Get all answers for this project and phase from ChecklistAnswer
  const ChecklistAnswer =
    require("../models/checklistAnswer.models.js").default;
  const allAnswers = await ChecklistAnswer.find({
    project_id: projectId,
    phase: phase,
  });

  // Group answers by sub_question
  const answersByQuestion = {};
  allAnswers.forEach((ans) => {
    if (!answersByQuestion[ans.sub_question]) {
      answersByQuestion[ans.sub_question] = {};
    }
    answersByQuestion[ans.sub_question][ans.role] = ans.answer;
  });

  // Count defects: where both executor and reviewer answered differently
  let totalDefectsInHistory = 0;
  checkpoints.forEach((cp) => {
    const question = cp.question;
    const roleAnswers = answersByQuestion[question];

    if (
      roleAnswers &&
      roleAnswers.executor !== undefined &&
      roleAnswers.reviewer !== undefined &&
      roleAnswers.executor !== roleAnswers.reviewer
    ) {
      totalDefectsInHistory++;
    }
  });

  const defectRate =
    totalCheckpoints > 0
      ? ((totalDefectsInHistory / totalCheckpoints) * 100).toFixed(2)
      : "0.00";

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        checklistId,
        totalCheckpoints,
        totalDefectsInHistory,
        defectRate: parseFloat(defectRate),
      },
      "Defect statistics fetched successfully"
    )
  );
});

/**
 * SUGGEST DEFECT CATEGORY
 * POST /api/v1/checkpoints/:checkpointId/suggest-category
 * Analyzes remark text and suggests the best matching defect category
 * Returns suggestion with confidence score
 */
export const suggestDefectCategory = asyncHandler(async (req, res) => {
  const { checkpointId } = req.params;
  const { remark } = req.body;

  // Allow "dummy" or any checkpointId for suggestion purposes
  // Only validate if it's not "dummy"
  if (checkpointId !== "dummy" && !mongoose.isValidObjectId(checkpointId)) {
    throw new ApiError(400, "Invalid checkpointId");
  }

  if (!remark || typeof remark !== "string" || remark.trim().length === 0) {
    return res.status(200).json(
      new ApiResponse(200, {
        suggestedCategoryId: null,
        confidence: 0,
        autoFill: false,
        reason: "Remark is empty or invalid",
      })
    );
  }

  // Skip checkpoint verification for dummy requests
  if (checkpointId !== "dummy") {
    // Fetch checkpoint to verify it exists
    const checkpoint = await Checkpoint.findById(checkpointId);
    if (!checkpoint) {
      throw new ApiError(404, "Checkpoint not found");
    }
  }

  // Import categorization service
  const { suggestCategory } = await import(
    "../services/categorizationService.js"
  );

  // Fetch template to get categories with keywords
  const Template = (await import("../models/template.models.js")).default;
  const template = await Template.findOne();

  if (!template || !template.defectCategories) {
    return res.status(200).json(
      new ApiResponse(200, {
        suggestedCategoryId: null,
        confidence: 0,
        autoFill: false,
        reason: "No categories available in template",
      })
    );
  }

  // Call categorization service
  const suggestion = suggestCategory(remark, template.defectCategories);

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        suggestedCategoryId: suggestion.suggestedCategoryId,
        categoryName: suggestion.categoryName,
        confidence: suggestion.confidence,
        autoFill: suggestion.autoFill,
        matchCount: suggestion.matchCount,
        tokenCount: suggestion.tokenCount,
      },
      "Category suggestion generated successfully"
    )
  );
});
