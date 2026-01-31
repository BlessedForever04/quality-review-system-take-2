import mongoose from "mongoose";

const stageSchema = new mongoose.Schema(
  {
    project_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Project",
      required: true,
    },
    stage_name: {
      type: String,
      required: true,
      trim: true,
    },
    stage_key: {
      type: String,
      required: false,
      trim: true,
      // Maps to template stage (e.g., 'stage1', 'stage2', 'stage3', etc.)
    },
    description: String,
    status: {
      type: String,
      enum: ["pending", "in_progress", "completed"],
      default: "pending",
      required: true,
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: false,
      default: null,
    },
    loopback_count: {
      type: Number,
      default: 0, // DEPRECATED: No longer used as TeamLeader cannot revert phases
    },
    conflict_count: {
      type: Number,
      default: 0, // Tracks how many times Reviewer reverted to Executor
    },
  },
  { timestamps: true }
);

const Stage = mongoose.model("Stage", stageSchema);

export default Stage;
