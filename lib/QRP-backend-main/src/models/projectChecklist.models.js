import mongoose from "mongoose";

const projectQuestionSchema = new mongoose.Schema(
  {
    text: { type: String, required: true, trim: true },
    executorAnswer: {
      type: String,
      enum: ["Yes", "No", "NA", null],
      default: null,
    },
    executorRemark: { type: String, default: "" },
    executorImages: {
      type: [
        {
          fileId: { type: String, required: true },
          filename: { type: String, required: true },
        },
      ],
      default: [],
    },
    reviewerAnswer: {
      type: String,
      enum: ["Yes", "No", "NA", null],
      default: null,
    },
    reviewerStatus: {
      type: String,
      enum: ["Approved", "Rejected", null],
      default: null,
    },
    reviewerRemark: { type: String, default: "" },
    reviewerImages: {
      type: [
        {
          fileId: { type: String, required: true },
          filename: { type: String, required: true },
        },
      ],
      default: [],
    },
    categoryId: { type: String, default: "" },
    severity: { type: String, default: "" },
    answeredBy: {
      executor: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        default: null,
      },
      reviewer: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        default: null,
      },
    },
    answeredAt: {
      executor: { type: Date, default: null },
      reviewer: { type: Date, default: null },
    },
  },
  { _id: true },
);

const projectSectionSchema = new mongoose.Schema(
  {
    sectionName: { type: String, required: true, trim: true },
    questions: { type: [projectQuestionSchema], default: [] },
  },
  { _id: true },
);

const projectGroupSchema = new mongoose.Schema(
  {
    groupName: { type: String, required: true, trim: true },
    questions: { type: [projectQuestionSchema], default: [] },
    sections: { type: [projectSectionSchema], default: [] },
    defectCount: { type: Number, default: 0 },
  },
  { _id: true },
);

const projectChecklistIterationSchema = new mongoose.Schema(
  {
    iterationNumber: { type: Number, required: true },
    groups: { type: [projectGroupSchema], default: [] },
    revertedAt: { type: Date, required: true },
    revertedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
    revertNotes: { type: String, default: "" },
    executorSubmittedAt: { type: Date, default: null },
    reviewerSubmittedAt: { type: Date, default: null },
  },
  { _id: true },
);

const projectChecklistSchema = new mongoose.Schema(
  {
    projectId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Project",
      required: true,
      index: true,
    },
    stageId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Stage",
      required: true,
      index: true,
    },
    stage: { type: String, required: true, trim: true },
    groups: { type: [projectGroupSchema], default: [] },
    iterations: { type: [projectChecklistIterationSchema], default: [] },
    currentIteration: { type: Number, default: 1 },
  },
  { timestamps: true },
);

projectChecklistSchema.index({ projectId: 1, stageId: 1 }, { unique: true });

const ProjectChecklist = mongoose.model(
  "ProjectChecklist",
  projectChecklistSchema,
);

export default ProjectChecklist;
