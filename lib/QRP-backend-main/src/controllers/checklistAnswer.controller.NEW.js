import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import Stage from "../models/stage.models.js";

/**
 * GET /api/projects/:projectId/checklist-answers?phase=1&role=executor
 * Retrieves all checklist answers for a specific project, phase, and role
 */
const getChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.query;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role) {
    throw new ApiError(400, "Phase and role query parameters are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  // Find the stage for this phase
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    return res
      .status(200)
      .json(new ApiResponse(200, {}, "No stage found for this phase"));
  }

  // Get project checklist for this stage
  const checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    return res
      .status(200)
      .json(new ApiResponse(200, {}, "No checklist found for this stage"));
  }

  // Extract answers for the specified role into a map structure
  const answerMap = {};

  checklist.groups.forEach(group => {
    // Direct questions in group
    group.questions.forEach(q => {
      const key = q.text;
      if (normalizedRole === "executor") {
        answerMap[key] = {
          answer: q.executorAnswer,
          remark: q.executorRemark || "",
          images: q.executorImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.executor ? { id: q.answeredBy.executor } : null,
          answered_at: q.answeredAt?.executor || null,
        };
      } else {
        answerMap[key] = {
          answer: q.reviewerAnswer,
          remark: q.reviewerRemark || "",
          images: q.reviewerImages || [],
          categoryId: q.categoryId || "",
          severity: q.severity || "",
          answered_by: q.answeredBy?.reviewer ? { id: q.answeredBy.reviewer } : null,
          answered_at: q.answeredAt?.reviewer || null,
        };
      }
    });
    
    // Questions in sections
    group.sections.forEach(section => {
      section.questions.forEach(q => {
        const key = q.text;
        if (normalizedRole === "executor") {
          answerMap[key] = {
            answer: q.executorAnswer,
            remark: q.executorRemark || "",
            images: q.executorImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.executor ? { id: q.answeredBy.executor } : null,
            answered_at: q.answeredAt?.executor || null,
          };
        } else {
          answerMap[key] = {
            answer: q.reviewerAnswer,
            remark: q.reviewerRemark || "",
            images: q.reviewerImages || [],
            categoryId: q.categoryId || "",
            severity: q.severity || "",
            answered_by: q.answeredBy?.reviewer ? { id: q.answeredBy.reviewer } : null,
            answered_at: q.answeredAt?.reviewer || null,
          };
        }
      });
    });
  });

  return res
    .status(200)
    .json(
      new ApiResponse(200, answerMap, "Checklist answers fetched successfully"),
    );
});

/**
 * PUT /api/projects/:projectId/checklist-answers
 * Saves/updates checklist answers for a specific project, phase, and role
 * Body: { phase, role, answers: { "sub_question": { answer, remark, images, categoryId, severity }, ... } }
 */
const saveChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role, answers } = req.body;
  console.log(
    "[saveChecklistAnswers] projectId=",
    projectId,
    "phase=",
    phase,
    "role=",
    role,
  );

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role || !answers) {
    throw new ApiError(400, "Phase, role, and answers are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  const userId = req.user?._id || null;

  // answers should be an object: { "sub_question": { answer, remark, images }, ... }
  if (typeof answers !== "object" || Array.isArray(answers)) {
    throw new ApiError(400, "Answers must be an object with sub-question keys");
  }

  // Find the stage for this phase
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    throw new ApiError(404, "Stage not found for this phase");
  }

  // Get project checklist for this stage
  const checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    throw new ApiError(404, "Checklist not found for this stage");
  }

  const savedAnswers = [];

  // Process each sub-question answer
  for (const [subQuestion, answerData] of Object.entries(answers)) {
    console.log("  ↳ Updating subQuestion=", subQuestion);
    if (!answerData || typeof answerData !== "object") {
      continue; // Skip invalid entries
    }

    const {
      answer,
      remark,
      images,
      categoryId,
      severity,
    } = answerData;

    // Find the question in the checklist
    let found = false;
    
    for (const group of checklist.groups) {
      // Search direct questions
      for (const q of group.questions) {
        if (q.text === subQuestion) {
          if (normalizedRole === "executor") {
            if (answer !== undefined) q.executorAnswer = answer;
            if (remark !== undefined) q.executorRemark = remark || "";
            if (images !== undefined) q.executorImages = Array.isArray(images) ? images : [];
            q.answeredBy.executor = userId;
            q.answeredAt.executor = new Date();
          } else {
            if (answer !== undefined) q.reviewerAnswer = answer;
            if (remark !== undefined) q.reviewerRemark = remark || "";
            if (images !== undefined) q.reviewerImages = Array.isArray(images) ? images : [];
            q.answeredBy.reviewer = userId;
            q.answeredAt.reviewer = new Date();
          }
          if (categoryId !== undefined) q.categoryId = categoryId || "";
          if (severity !== undefined) q.severity = severity || "";
          found = true;
          savedAnswers.push({ question: subQuestion, updated: true });
          break;
        }
      }
      
      if (found) break;
      
      // Search questions in sections
      for (const section of group.sections) {
        for (const q of section.questions) {
          if (q.text === subQuestion) {
            if (normalizedRole === "executor") {
              if (answer !== undefined) q.executorAnswer = answer;
              if (remark !== undefined) q.executorRemark = remark || "";
              if (images !== undefined) q.executorImages = Array.isArray(images) ? images : [];
              q.answeredBy.executor = userId;
              q.answeredAt.executor = new Date();
            } else {
              if (answer !== undefined) q.reviewerAnswer = answer;
              if (remark !== undefined) q.reviewerRemark = remark || "";
              if (images !== undefined) q.reviewerImages = Array.isArray(images) ? images : [];
              q.answeredBy.reviewer = userId;
              q.answeredAt.reviewer = new Date();
            }
            if (categoryId !== undefined) q.categoryId = categoryId || "";
            if (severity !== undefined) q.severity = severity || "";
            found = true;
            savedAnswers.push({ question: subQuestion, updated: true });
            break;
          }
        }
        if (found) break;
      }
      if (found) break;
    }

    if (!found) {
      console.log(`  ⚠ Question not found: ${subQuestion}`);
    }
  }

  // Save the updated checklist
  await checklist.save();

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { saved_count: savedAnswers.length },
        "Checklist answers saved successfully",
      ),
    );
});

/**
 * POST /api/projects/:projectId/checklist-answers/submit
 * Marks checklist answers as submitted for a specific project, phase, and role
 */
const submitChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.body;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role) {
    throw new ApiError(400, "Phase and role are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  // Find or create submission record in ChecklistApproval
  const record = await ChecklistApproval.findOneAndUpdate(
    { project_id: projectId, phase: phaseNum },
    {
      $set: {
        [`${normalizedRole}_submitted`]: true,
        [`${normalizedRole}_submitted_at`]: new Date(),
      },
    },
    { upsert: true, new: true },
  );

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        record,
        `${normalizedRole} checklist submitted successfully`,
      ),
    );
});

/**
 * GET /api/projects/:projectId/checklist-answers/submission-status
 * Gets submission status for a specific project, phase, and role
 */
const getSubmissionStatus = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.query;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid project ID");
  }

  if (!phase || !role) {
    throw new ApiError(400, "Phase and role query parameters are required");
  }

  const phaseNum = parseInt(phase);
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase number");
  }

  const normalizedRole = role.toLowerCase();
  if (!["executor", "reviewer"].includes(normalizedRole)) {
    throw new ApiError(400, "Role must be 'executor' or 'reviewer'");
  }

  const record = await ChecklistApproval.findOne({
    project_id: projectId,
    phase: phaseNum,
  });

  const isSubmitted = record?.[`${normalizedRole}_submitted`] || false;
  const submittedAt = record?.[`${normalizedRole}_submitted_at`] || null;

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        {
          is_submitted: isSubmitted,
          submitted_at: submittedAt,
        },
        "Submission status fetched successfully",
      ),
    );
});

export {
  getChecklistAnswers,
  saveChecklistAnswers,
  submitChecklistAnswers,
  getSubmissionStatus,
};
