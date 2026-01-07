import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ChecklistAnswer from "../models/checklistAnswer.models.js";
import Checkpoint from "../models/checkpoint.models.js";

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

  // Fetch all answers for this project/phase/role
  const answers = await ChecklistAnswer.find({
    project_id: projectId,
    phase: phaseNum,
    role: normalizedRole,
  })
    .populate("answered_by", "name email")
    .sort({ sub_question: 1, answered_at: -1 });

  // Transform to a map structure: { sub_question: { answer, remark, images, ... } }
  const answerMap = {};
  answers.forEach((ans) => {
    answerMap[ans.sub_question] = {
      answer: ans.answer,
      remark: ans.remark || "",
      images: ans.images || [],
      answered_by: ans.answered_by
        ? {
            id: ans.answered_by._id,
            name: ans.answered_by.name,
            email: ans.answered_by.email,
          }
        : null,
      answered_at: ans.answered_at,
      is_submitted: ans.is_submitted,
    };
  });

  return res
    .status(200)
    .json(
      new ApiResponse(200, answerMap, "Checklist answers fetched successfully")
    );
});

/**
 * PUT /api/projects/:projectId/checklist-answers
 * Saves/updates checklist answers for a specific project, phase, and role
 * Body: { phase, role, answers: { "sub_question": { answer, remark, images }, ... } }
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
    role
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

  // Allow unauthenticated usage: answered_by may be null
  const userId = req.user?._id || null;

  // answers should be an object: { "sub_question": { answer, remark, images }, ... }
  if (typeof answers !== "object" || Array.isArray(answers)) {
    throw new ApiError(400, "Answers must be an object with sub-question keys");
  }

  // If any save occurs, consider checklist un-submitted for this role to allow edits
  await ChecklistAnswer.updateMany(
    { project_id: projectId, phase: phaseNum, role: normalizedRole },
    { $set: { is_submitted: false } }
  );

  const savedAnswers = [];

  // Process each sub-question answer
  for (const [subQuestion, answerData] of Object.entries(answers)) {
    console.log("  ↳ Upserting subQuestion=", subQuestion);
    if (!answerData || typeof answerData !== "object") {
      continue; // Skip invalid entries
    }

    const { answer, remark, images, categoryId, severity } = answerData;

    // Validate answer value
    if (answer !== null && answer !== "Yes" && answer !== "No") {
      continue; // Skip invalid answer values
    }

    // Upsert the answer
    const updatedAnswer = await ChecklistAnswer.findOneAndUpdate(
      {
        project_id: projectId,
        phase: phaseNum,
        role: normalizedRole,
        sub_question: subQuestion,
      },
      {
        $set: {
          answer: answer,
          remark: remark || "",
          images: Array.isArray(images) ? images : [],
          answered_by: userId,
          answered_at: new Date(),
          // Any edit clears submission until explicitly submitted again
          is_submitted: false,
        },
      },
      {
        upsert: true,
        new: true,
        runValidators: true,
      }
    );

    savedAnswers.push(updatedAnswer);

    // If categoryId and/or severity are provided, update the checkpoint defect data
    if (categoryId || severity) {
      try {
        const checkpoint = await Checkpoint.findOne({
          project_id: projectId,
          phase: phaseNum,
          sub_question: subQuestion,
        });

        if (checkpoint) {
          const updateData = {};
          if (categoryId) {
            updateData["defect.categoryId"] = categoryId;
          }
          if (severity) {
            updateData["defect.severity"] = severity;
          }

          await Checkpoint.findByIdAndUpdate(checkpoint._id, {
            $set: updateData,
          });
          console.log(
            `  ✓ Updated checkpoint defect category/severity for ${subQuestion}`
          );
        }
      } catch (err) {
        console.log(
          `  ⚠ Could not update checkpoint category/severity: ${err.message}`
        );
        // Don't fail the whole save if checkpoint update fails
      }
    }
  }

  // AFTER saving answers, detect defects by comparing executor vs reviewer answers
  // Find all answers for this project and phase (both roles)
  const allAnswers = await ChecklistAnswer.find({
    project_id: projectId,
    phase: phaseNum,
  });

  // Group by sub_question and check if executor/reviewer answers differ
  const answersByQuestion = {};
  allAnswers.forEach((ans) => {
    if (!answersByQuestion[ans.sub_question]) {
      answersByQuestion[ans.sub_question] = {};
    }
    answersByQuestion[ans.sub_question][ans.role] = ans.answer;
  });

  // Check each question for defects and update Checkpoint model
  for (const [subQuestion, roleAnswers] of Object.entries(answersByQuestion)) {
    const executorAns = roleAnswers.executor;
    const reviewerAns = roleAnswers.reviewer;

    // Only update defect if both have answered
    if (executorAns !== undefined && reviewerAns !== undefined) {
      const answersMatch = executorAns === reviewerAns;

      // Find checkpoint by matching sub_question text (since ChecklistAnswer uses text as key)
      const Checklist = require("../models/checklist.models.js").default;
      const Checkpoint = require("../models/checkpoint.models.js").default;

      // Find checkpoint in this phase for this project
      const checkpoint = await Checkpoint.findOne({
        $expr: {
          $eq: [{ $toString: "$question" }, subQuestion],
        },
      });

      if (checkpoint) {
        const wasDefectDetected = checkpoint.defect.isDetected;
        checkpoint.defect.isDetected = !answersMatch;

        if (!answersMatch) {
          // Defect detected: answers differ
          checkpoint.defect.detectedAt = new Date();
          if (!wasDefectDetected) {
            checkpoint.defect.historyCount =
              (checkpoint.defect.historyCount || 0) + 1;
          }
        } else {
          // No defect: answers match
          checkpoint.defect.isDetected = false;
          checkpoint.defect.categoryId = null;
          checkpoint.defect.detectedAt = null;
        }

        await checkpoint.save();
      }
    }
  }

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { count: savedAnswers.length },
        "Checklist answers saved successfully"
      )
    );
});

/**
 * POST /api/projects/:projectId/checklist-answers/submit
 * Marks all answers for a specific project/phase/role as submitted
 * Body: { phase, role }
 */
const submitChecklistAnswers = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase, role } = req.body;
  console.log(
    "[submitChecklistAnswers] projectId=",
    projectId,
    "phase=",
    phase,
    "role=",
    role
  );

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

  // Allow unauthenticated submissions

  // Mark all answers for this project/phase/role as submitted
  const result = await ChecklistAnswer.updateMany(
    {
      project_id: projectId,
      phase: phaseNum,
      role: normalizedRole,
    },
    {
      $set: {
        is_submitted: true,
      },
    }
  );
  console.log("[submitChecklistAnswers] updated docs =", result.modifiedCount);

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        { updated: result.modifiedCount },
        "Checklist submitted successfully"
      )
    );
});

/**
 * GET /api/projects/:projectId/checklist-answers/submission-status?phase=1&role=executor
 * Checks if a specific project/phase/role has been submitted
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

  // Check if any answers exist with is_submitted = true
  const submittedAnswer = await ChecklistAnswer.findOne({
    project_id: projectId,
    phase: phaseNum,
    role: normalizedRole,
    is_submitted: true,
  });

  const isSubmitted = !!submittedAnswer;
  const count = await ChecklistAnswer.countDocuments({
    project_id: projectId,
    phase: phaseNum,
    role: normalizedRole,
  });

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        is_submitted: isSubmitted,
        answer_count: count,
        submitted_at: submittedAnswer?.answered_at,
      },
      "Submission status fetched successfully"
    )
  );
});

export {
  getChecklistAnswers,
  saveChecklistAnswers,
  submitChecklistAnswers,
  getSubmissionStatus,
};
