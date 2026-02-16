import mongoose from "mongoose";

const projectSchema = new mongoose.Schema(
  {
    project_no: {
      type: String,
      trim: true,
    },
    internal_order_no: {
      type: String,
      trim: true,
    },
    project_name: {
      type: String,
      required: true,
      trim: true,
    },
    description: {
      type: String,
      trim: true,
    },
    status: {
      type: String,
      enum: ["pending", "in_progress", "completed"],
      default: "pending",
      required: true,
    },
    priority: {
      type: String,
      enum: ["low", "medium", "high"],
      default: "medium",
    },
    start_date: {
      type: Date,
      required: true,
    },
    end_date: {
      type: Date,
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    isReviewApplicable: {
      type: Boolean,
      default: null,
    },
  },
  {
    timestamps: true, // adds createdAt and updatedAt automatically
  },
);

export default mongoose.model("Project", projectSchema);
