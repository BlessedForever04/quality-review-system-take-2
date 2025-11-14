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
      required: true,
    },
  },
  { timestamps: true }
);

const Stage = mongoose.model("Stage", stageSchema);


export default Stage;
