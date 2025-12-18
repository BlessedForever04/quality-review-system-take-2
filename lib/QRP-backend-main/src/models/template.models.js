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
});

// Checklist template schema (nested)
const checklistTemplateSchema = new mongoose.Schema({
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
      default: "Default Quality Review Template"
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
      ref: 'User',
    },
  },
  {
    timestamps: true, // adds createdAt and updatedAt
  }
);

const Template = mongoose.model("Template", templateSchema);

export default Template;
