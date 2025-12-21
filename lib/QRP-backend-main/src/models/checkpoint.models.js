import mongoose from "mongoose";

/**
 * CHECKPOINT MODEL - Adapted from V3
 * Represents a single checkpoint (question) within a checklist
 * Stores responses from both executor and reviewer roles
 */
const checkpointSchema = new mongoose.Schema(
  {
    // Links to parent checklist
    checklistId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Checklist",
      required: true,
      index: true,
    },

    // The question/checkpoint text
    question: {
      type: String,
      required: true,
      trim: true,
    },

    // Reference to defect category (from template)
    categoryId: {
      type: String,
      trim: true,
    },

    // Executor response
    executorResponse: {
      answer: {
        type: Boolean, // true = Yes, false = No, null = not answered
        default: null,
      },
      images: [
        {
          data: Buffer, // Store image as Buffer (from V3)
          contentType: String,
        },
      ],
      remark: {
        type: String,
        trim: true,
      },
      respondedAt: Date,
    },

    // Reviewer response
    reviewerResponse: {
      answer: {
        type: Boolean,
        default: null,
      },
      images: [
        {
          data: Buffer,
          contentType: String,
        },
      ],
      remark: String,
      reviewedAt: Date,
    },
  },
  {
    timestamps: true, // adds createdAt and updatedAt
  }
);

// Index for faster queries
checkpointSchema.index({ checklistId: 1, createdAt: 1 });

const Checkpoint = mongoose.model("Checkpoint", checkpointSchema);

export default Checkpoint;
