import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";

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
 * Defect count increments when: executor says "Yes" AND reviewer says "No"
 * No increment when: executor says "No" AND reviewer says "Yes"
 */
const calculateDefectCount = (group) => {
  let defectCount = 0;

  // Count defects in direct questions
  for (const question of group.questions) {
    if (question.executorAnswer === "Yes" && question.reviewerAnswer === "No") {
      defectCount++;
    }
  }

  // Count defects in section questions
  for (const section of group.sections) {
    for (const question of section.questions) {
      if (
        question.executorAnswer === "Yes" &&
        question.reviewerAnswer === "No"
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

  // Recalculate defect count for the group
  group.defectCount = calculateDefectCount(group);

  await checklist.save();

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

  // Recalculate defect count for the group
  group.defectCount = calculateDefectCount(group);

  await checklist.save();

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
  }).populate('iterations.revertedBy', 'name email');

  if (!checklist) {
    return res
      .status(200)
      .json(
        new ApiResponse(
          200,
          { iterations: [], currentIteration: 1 },
          "No checklist found"
        )
      );
  }

  return res
    .status(200)
    .json(
      new ApiResponse(
        200,
        {
          iterations: checklist.iterations,
          currentIteration: checklist.currentIteration,
          totalIterations: checklist.iterations.length,
        },
        "Iterations fetched successfully"
      )
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
};
