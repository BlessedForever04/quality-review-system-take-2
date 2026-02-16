import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";
import { deleteImagesByFileIds } from "../gridfs.js";

const allowedExecutorAnswers = ["Yes", "No", "NA", null];
const allowedReviewerStatuses = ["Approved", "Rejected", null];

const inferStageKey = (stageName = "") => {
  const lower = stageName.toLowerCase();
  // Match "phase X" or "stage X" where X is 1-99
  const match = lower.match(/(?:phase|stage)\s*(\d{1,2})/);
  if (match) {
    const phaseNum = parseInt(match[1]);
    return `stage${phaseNum}`;
  }
  return null;
};

const mapTemplateToGroups = (stageTemplates = []) => {
  return stageTemplates.map((group) => ({
    groupName: (group?.text || "").trim(),
    defectCount: 0,
    questions: (group?.checkpoints || []).map((cp) => ({
      text: (cp?.text || "").trim(),
      executorAnswer: null,
      executorRemark: "",
      executorImages: [],
      reviewerAnswer: null,
      reviewerStatus: null,
      reviewerRemark: "",
      reviewerImages: [],
      categoryId: "",
      severity: "",
      answeredBy: { executor: null, reviewer: null },
      answeredAt: { executor: null, reviewer: null },
    })),
    sections: (group?.sections || []).map((sec) => ({
      sectionName: (sec?.text || "").trim(),
      questions: (sec?.checkpoints || []).map((cp) => ({
        text: (cp?.text || "").trim(),
        executorAnswer: null,
        executorRemark: "",
        executorImages: [],
        reviewerAnswer: null,
        reviewerStatus: null,
        reviewerRemark: "",
        reviewerImages: [],
        categoryId: "",
        severity: "",
        answeredBy: { executor: null, reviewer: null },
        answeredAt: { executor: null, reviewer: null },
      })),
    })),
  }));
};

const ensureProjectChecklist = async ({ projectId, stageDoc }) => {
  const existing = await ProjectChecklist.findOne({
    projectId,
    stageId: stageDoc._id,
  });
  if (existing) return existing;

  const template = await Template.findOne();
  if (!template) {
    throw new ApiError(
      404,
      "Template not found. Please create a template first.",
    );
  }

  const stageKey = inferStageKey(stageDoc.stage_name) || "stage1";
  const groups = mapTemplateToGroups(template[stageKey] || []);

  const created = await ProjectChecklist.create({
    projectId,
    stageId: stageDoc._id,
    stage: stageDoc.stage_name,
    groups,
  });
  return created;
};

const findQuestionInGroup = (group, questionId) => {
  const direct = group.questions.id(questionId);
  if (direct) {
    return { question: direct, section: null };
  }
  for (const section of group.sections) {
    const nested = section.questions.id(questionId);
    if (nested) {
      return { question: nested, section };
    }
  }
  return { question: null, section: null };
};

/**
 * Calculate defect count for a group based on executor and reviewer answers
 * Defect count increments when: executor and reviewer answers differ (mismatch)
 */
const calculateDefectCount = (group) => {
  let defectCount = 0;

  // Count defects in direct questions (any mismatch between executor and reviewer)
  for (const question of group.questions) {
    if (
      question.executorAnswer &&
      question.reviewerAnswer &&
      question.executorAnswer !== question.reviewerAnswer
    ) {
      defectCount++;
    }
  }

  // Count defects in section questions (any mismatch between executor and reviewer)
  for (const section of group.sections) {
    for (const question of section.questions) {
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
};

const getProjectChecklist = asyncHandler(async (req, res) => {
  const { projectId, stageId } = req.params;

  if (
    !mongoose.isValidObjectId(projectId) ||
    !mongoose.isValidObjectId(stageId)
  ) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }

  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId });
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  return res
    .status(200)
    .json(
      new ApiResponse(200, checklist, "Project checklist fetched successfully"),
    );
});

const updateExecutorAnswer = asyncHandler(async (req, res) => {
  const { projectId, stageId, groupId, questionId } = req.params;
  const { answer, remark, images, categoryId, severity } = req.body;

  if (
    !mongoose.isValidObjectId(projectId) ||
    !mongoose.isValidObjectId(stageId)
  ) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  if (
    !mongoose.isValidObjectId(groupId) ||
    !mongoose.isValidObjectId(questionId)
  ) {
    throw new ApiError(400, "Invalid groupId or questionId");
  }

  if (!allowedExecutorAnswers.includes(answer === undefined ? null : answer)) {
    throw new ApiError(400, "executorAnswer must be Yes, No, NA, or null");
  }

  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId });
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const group = checklist.groups.id(groupId);
  if (!group) {
    throw new ApiError(404, "Checklist group not found");
  }

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) {
    throw new ApiError(404, "Question not found in this group");
  }

  // Track images to delete before updating
  let imagesToDelete = [];
  if (images !== undefined) {
    const newImages = Array.isArray(images) ? images : [];
    const oldImages = question.executorImages || [];
    // Find images that are being removed
    imagesToDelete = oldImages.filter((oldImg) => !newImages.includes(oldImg));
  }

  if (answer !== undefined) {
    question.executorAnswer = answer;
  }
  if (remark !== undefined) {
    question.executorRemark = remark || "";
  }
  if (images !== undefined) {
    question.executorImages = Array.isArray(images) ? images : [];
  }
  if (categoryId !== undefined) {
    question.categoryId = categoryId || "";
  }
  if (severity !== undefined) {
    question.severity = severity || "";
  }

  const userId = req.user?._id || null;
  question.answeredBy.executor = userId;
  question.answeredAt.executor = new Date();

  // NOTE: We don't recalculate defectCount here because it's cumulative
  // Defect count is only incremented when reviewer submits or reverts

  await checklist.save();

  // Delete removed images from GridFS
  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (error) {
      // Don't fail the request if image deletion fails
    }
  }

  return res
    .status(200)
    .json(new ApiResponse(200, group.toObject(), "Executor response updated"));
});

const updateReviewerStatus = asyncHandler(async (req, res) => {
  const { projectId, stageId, groupId, questionId } = req.params;
  const { answer, status, remark, images, categoryId, severity } = req.body;

  if (
    !mongoose.isValidObjectId(projectId) ||
    !mongoose.isValidObjectId(stageId)
  ) {
    throw new ApiError(400, "Invalid projectId or stageId");
  }
  if (
    !mongoose.isValidObjectId(groupId) ||
    !mongoose.isValidObjectId(questionId)
  ) {
    throw new ApiError(400, "Invalid groupId or questionId");
  }

  if (answer !== undefined && !["Yes", "No", null].includes(answer)) {
    throw new ApiError(400, "reviewerAnswer must be Yes, No, or null");
  }

  if (!allowedReviewerStatuses.includes(status === undefined ? null : status)) {
    throw new ApiError(
      400,
      "reviewerStatus must be Approved, Rejected, or null",
    );
  }

  const stageDoc = await Stage.findOne({ _id: stageId, project_id: projectId });
  if (!stageDoc) {
    throw new ApiError(404, "Stage not found for this project");
  }

  const checklist = await ensureProjectChecklist({ projectId, stageDoc });

  const group = checklist.groups.id(groupId);
  if (!group) {
    throw new ApiError(404, "Checklist group not found");
  }

  const { question } = findQuestionInGroup(group, questionId);
  if (!question) {
    throw new ApiError(404, "Question not found in this group");
  }

  // Track images to delete before updating
  let imagesToDelete = [];
  if (images !== undefined) {
    const newImages = Array.isArray(images) ? images : [];
    const oldImages = question.reviewerImages || [];
    // Find images that are being removed
    imagesToDelete = oldImages.filter((oldImg) => !newImages.includes(oldImg));
  }

  if (answer !== undefined) {
    question.reviewerAnswer = answer;
  }
  if (status !== undefined) {
    question.reviewerStatus = status;
  }
  if (remark !== undefined) {
    question.reviewerRemark = remark || "";
  }
  if (images !== undefined) {
    question.reviewerImages = Array.isArray(images) ? images : [];
  }
  if (categoryId !== undefined) {
    question.categoryId = categoryId || "";
  }
  if (severity !== undefined) {
    question.severity = severity || "";
  }

  const userId = req.user?._id || null;
  question.answeredBy.reviewer = userId;
  question.answeredAt.reviewer = new Date();

  // NOTE: We don't recalculate defectCount here because it's cumulative
  // Defect count is only incremented when reviewer submits or reverts

  await checklist.save();

  // Delete removed images from GridFS
  if (imagesToDelete.length > 0) {
    try {
      await deleteImagesByFileIds(imagesToDelete);
    } catch (error) {
      // Don't fail the request if image deletion fails
    }
  }

  return res
    .status(200)
    .json(new ApiResponse(200, group.toObject(), "Reviewer decision updated"));
});

// GET iterations for a project checklist
const getChecklistIterations = asyncHandler(async (req, res) => {
  const { projectId, stageId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }
  if (!mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid stageId");
  }

  const checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stageId,
  }).populate("iterations.revertedBy", "name email");

  if (!checklist) {
    return res
      .status(200)
      .json(
        new ApiResponse(
          200,
          { iterations: [], currentIteration: 1 },
          "No checklist found",
        ),
      );
  }

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        iterations: checklist.iterations,
        currentIteration: checklist.currentIteration,
        totalIterations: checklist.iterations.length,
      },
      "Iterations fetched successfully",
    ),
  );
});

/**
 * GET DEFECT RATES PER ITERATION
 * GET /api/v1/project-checklists/:projectId/defect-rates
 * Returns defect rate for each iteration of a specific phase
 * Query params: phase (required)
 */
const getDefectRatesPerIteration = asyncHandler(async (req, res) => {
  const { projectId } = req.params;
  const { phase } = req.query;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  const phaseNum = parseInt(phase || "1");
  if (isNaN(phaseNum) || phaseNum < 1) {
    throw new ApiError(400, "Invalid phase");
  }

  // Find the stage
  const stageKey = `stage${phaseNum}`;
  const stage = await Stage.findOne({
    project_id: projectId,
    stage_key: stageKey,
  });

  if (!stage) {
    return res.status(200).json(
      new ApiResponse(
        200,
        {
          iterations: [],
          currentDefectRate: 0,
        },
        "No stage found for this phase",
      ),
    );
  }

  // Get the checklist
  const checklist = await ProjectChecklist.findOne({
    projectId: projectId,
    stageId: stage._id,
  });

  if (!checklist) {
    return res.status(200).json(
      new ApiResponse(
        200,
        {
          iterations: [],
          currentDefectRate: 0,
        },
        "No checklist found",
      ),
    );
  }

  // Helper function to calculate current mismatches for ongoing iteration
  const calculateCurrentMismatches = (groups) => {
    let totalQuestions = 0;
    let currentMismatches = 0;

    groups.forEach((group) => {
      // Direct questions under group
      if (group.questions && Array.isArray(group.questions)) {
        group.questions.forEach((q) => {
          totalQuestions++;
          const exAns = q.executorAnswer;
          const revAns = q.reviewerStatus;
          // Count as mismatch if both answered and they differ
          if (
            exAns !== null &&
            exAns !== undefined &&
            revAns !== null &&
            revAns !== undefined &&
            exAns !== revAns
          ) {
            currentMismatches++;
          }
        });
      }

      // Section-based questions
      if (group.sections && Array.isArray(group.sections)) {
        group.sections.forEach((section) => {
          if (section.questions && Array.isArray(section.questions)) {
            section.questions.forEach((q) => {
              totalQuestions++;
              const exAns = q.executorAnswer;
              const revAns = q.reviewerStatus;
              if (
                exAns !== null &&
                exAns !== undefined &&
                revAns !== null &&
                revAns !== undefined &&
                exAns !== revAns
              ) {
                currentMismatches++;
              }
            });
          }
        });
      }
    });

    const defectRate =
      totalQuestions > 0
        ? parseFloat(((currentMismatches / totalQuestions) * 100).toFixed(2))
        : 0;

    return {
      totalQuestions,
      totalDefects: currentMismatches,
      defectRate,
    };
  };

  // Calculate defect rate for each iteration using stored defectCount
  // Each iteration shows NEW defects found in that iteration only
  const iterationsWithRates = [];
  let previousIterationDefects = 0;

  for (let i = 0; i < checklist.iterations.length; i++) {
    const iteration = checklist.iterations[i];
    let totalQuestions = 0;
    let cumulativeDefects = 0;

    // Sum up defect counts from groups (this is cumulative)
    iteration.groups.forEach((group) => {
      cumulativeDefects += group.defectCount || 0;

      // Count total questions
      if (group.questions && Array.isArray(group.questions)) {
        totalQuestions += group.questions.length;
      }
      if (group.sections && Array.isArray(group.sections)) {
        group.sections.forEach((section) => {
          if (section.questions && Array.isArray(section.questions)) {
            totalQuestions += section.questions.length;
          }
        });
      }
    });

    // Calculate NEW defects in this iteration only (not cumulative)
    const newDefectsInIteration = cumulativeDefects - previousIterationDefects;
    previousIterationDefects = cumulativeDefects;

    const defectRate =
      totalQuestions > 0
        ? parseFloat(
            ((newDefectsInIteration / totalQuestions) * 100).toFixed(2),
          )
        : 0;

    iterationsWithRates.push({
      iterationNumber: iteration.iterationNumber,
      revertedAt: iteration.revertedAt,
      revertNotes: iteration.revertNotes,
      totalQuestions,
      totalDefects: newDefectsInIteration,
      defectRate,
    });
  }

  // Calculate current defect rate (ongoing iteration) from current mismatches
  const currentStats = calculateCurrentMismatches(checklist.groups);

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        iterations: iterationsWithRates,
        current: {
          iterationNumber: checklist.currentIteration || 1,
          ...currentStats,
        },
      },
      "Defect rates per iteration fetched successfully",
    ),
  );
});

/**
 * GET OVERALL DEFECT RATE FOR PROJECT
 * GET /api/v1/project-checklists/:projectId/overall-defect-rate
 * Returns the overall defect rate across all phases
 */
const getOverallDefectRate = asyncHandler(async (req, res) => {
  const { projectId } = req.params;

  if (!mongoose.isValidObjectId(projectId)) {
    throw new ApiError(400, "Invalid projectId");
  }

  // Get all stages for this project
  const stages = await Stage.find({ project_id: projectId });

  if (!stages || stages.length === 0) {
    return res.status(200).json(
      new ApiResponse(
        200,
        {
          overallDefectRate: 0,
          totalQuestions: 0,
          totalDefects: 0,
          phaseBreakdown: [],
        },
        "No stages found for this project",
      ),
    );
  }

  let grandTotalQuestions = 0;
  let grandTotalDefects = 0;
  const phaseBreakdown = [];

  // Helper function to calculate current mismatches
  const calculateCurrentMismatches = (groups) => {
    let totalQuestions = 0;
    let totalDefects = 0;

    groups.forEach((group) => {
      // Direct questions
      if (group.questions && Array.isArray(group.questions)) {
        group.questions.forEach((q) => {
          totalQuestions++;
          const exAns = q.executorAnswer;
          const revAns = q.reviewerStatus;
          if (
            exAns !== null &&
            exAns !== undefined &&
            revAns !== null &&
            revAns !== undefined &&
            exAns !== revAns
          ) {
            totalDefects++;
          }
        });
      }

      // Section-based questions
      if (group.sections && Array.isArray(group.sections)) {
        group.sections.forEach((section) => {
          if (section.questions && Array.isArray(section.questions)) {
            section.questions.forEach((q) => {
              totalQuestions++;
              const exAns = q.executorAnswer;
              const revAns = q.reviewerStatus;
              if (
                exAns !== null &&
                exAns !== undefined &&
                revAns !== null &&
                revAns !== undefined &&
                exAns !== revAns
              ) {
                totalDefects++;
              }
            });
          }
        });
      }
    });

    return { totalQuestions, totalDefects };
  };

  // Process each stage/phase
  for (const stage of stages) {
    const checklist = await ProjectChecklist.findOne({
      projectId: projectId,
      stageId: stage._id,
    });

    if (checklist) {
      let totalQuestionsInPhase = 0;
      let totalDefectsInPhase = 0;

      // Count total questions
      checklist.groups.forEach((group) => {
        if (group.questions && Array.isArray(group.questions)) {
          totalQuestionsInPhase += group.questions.length;
        }
        if (group.sections && Array.isArray(group.sections)) {
          group.sections.forEach((section) => {
            if (section.questions && Array.isArray(section.questions)) {
              totalQuestionsInPhase += section.questions.length;
            }
          });
        }
      });

      // Calculate total defects for this phase
      if (checklist.iterations && checklist.iterations.length > 0) {
        // If iterations exist, use the accumulated defectCount from the last iteration
        // Plus any new current mismatches
        const lastIteration =
          checklist.iterations[checklist.iterations.length - 1];
        let accumulatedDefects = 0;

        lastIteration.groups.forEach((group) => {
          accumulatedDefects += group.defectCount || 0;
        });

        // Add current mismatches that haven't been accumulated yet
        const currentMismatches = calculateCurrentMismatches(checklist.groups);
        totalDefectsInPhase =
          accumulatedDefects + currentMismatches.totalDefects;
      } else {
        // No iterations yet, just use current mismatches
        const currentMismatches = calculateCurrentMismatches(checklist.groups);
        totalDefectsInPhase = currentMismatches.totalDefects;
      }

      grandTotalQuestions += totalQuestionsInPhase;
      grandTotalDefects += totalDefectsInPhase;

      const phaseDefectRate =
        totalQuestionsInPhase > 0
          ? parseFloat(
              ((totalDefectsInPhase / totalQuestionsInPhase) * 100).toFixed(2),
            )
          : 0;

      phaseBreakdown.push({
        phase: stage.stage_key,
        stageName: stage.stage_name,
        totalQuestions: totalQuestionsInPhase,
        totalDefects: totalDefectsInPhase,
        defectRate: phaseDefectRate,
      });
    }
  }

  const overallDefectRate =
    grandTotalQuestions > 0
      ? parseFloat(((grandTotalDefects / grandTotalQuestions) * 100).toFixed(2))
      : 0;

  return res.status(200).json(
    new ApiResponse(
      200,
      {
        overallDefectRate,
        totalQuestions: grandTotalQuestions,
        totalDefects: grandTotalDefects,
        phaseBreakdown,
      },
      "Overall defect rate fetched successfully",
    ),
  );
});

export {
  getProjectChecklist,
  updateExecutorAnswer,
  updateReviewerStatus,
  getChecklistIterations,
  ensureProjectChecklist,
  mapTemplateToGroups,
  inferStageKey,
  getDefectRatesPerIteration,
  getOverallDefectRate,
};
