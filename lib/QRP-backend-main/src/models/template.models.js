import mongoose from "mongoose";

/**
 * TEMPLATE MODEL - Adapted from V3
 * Single document in the system that holds all checklist templates
 * Organized by stages (phase1, phase2, phase3)
 * Each stage contains checklist groups with their checkpoints
 */

// Checkpoint template schema (nested)
const checkpointTemplateSchema = new mongoose.Schema({
  text: {
    type: String,
    required: true,
    trim: true,
  },
  categoryId: {
    type: String,
    trim: true,
  },
});

// Section template schema (nested within checklists)
// Sections are optional containers that can hold checkpoints
const sectionTemplateSchema = new mongoose.Schema({
  text: {
    type: String,
    required: true,
    trim: true,
  },
  checkpoints: {
    type: [checkpointTemplateSchema],
    default: [],
  },
});

// Checklist template schema (nested)
const checklistTemplateSchema = new mongoose.Schema({
  text: {
    type: String,
    required: true,
    trim: true,
  },
  // Direct questions on the group (optional)
  checkpoints: {
    type: [checkpointTemplateSchema],
    default: [],
  },
  // Sections within the group (optional)
  sections: {
    type: [sectionTemplateSchema],
    default: [],
  },
});

/**
 * Main Template Schema
 * Stores templates for all three phases/stages
 * Only ONE template document should exist in the system
 */
const templateSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      default: "Default Quality Review Template",
    },

    // Defect Categories
    defectCategories: {
      type: [
        {
          name: { type: String, required: true, trim: true },
          color: { type: String, trim: true, default: "#2196F3" }, // Optional, defaults to blue
          keywords: {
            type: [String],
            default: [],
          }, // Keywords for auto-detection during review
        },
      ],
      default: [],
    },

    // Phase/Stage 1 templates
    stage1: {
      type: [checklistTemplateSchema],
      default: [],
    },

    // Phase/Stage 2 templates
    stage2: {
      type: [checklistTemplateSchema],
      default: [],
    },

    // Phase/Stage 3 templates
    stage3: {
      type: [checklistTemplateSchema],
      default: [],
    },

    // Track who last modified the template (optional)
    modifiedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },
  },
  {
    timestamps: true, // adds createdAt and updatedAt
  }
);

const Template = mongoose.model("Template", templateSchema);

export default Template;
