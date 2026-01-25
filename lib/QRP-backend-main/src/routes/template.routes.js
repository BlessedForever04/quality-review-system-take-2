import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import { requireAdmin } from "../middleware/role.middleware.js";
import {
  createTemplate,
  getTemplate,
  addChecklistToTemplate,
  updateChecklistInTemplate,
  deleteChecklistFromTemplate,
  addCheckpointToTemplate,
  updateCheckpointInTemplate,
  deleteCheckpointFromTemplate,
  seedTemplate,
  updateDefectCategories,
  addSectionToChecklist,
  updateSectionInChecklist,
  deleteSectionFromChecklist,
  addCheckpointToSection,
  updateCheckpointInSection,
  deleteCheckpointFromSection,
  addStageToTemplate,
  deleteStageFromTemplate,
  getAllStages,
  resetTemplate,
} from "../controllers/template.controller.js";

const router = express.Router();

/**
 * TEMPLATE ROUTES
 * Base path: /api/v1/templates
 *
 * Note: Only ONE template exists in the system
 */

// Seed template with sample data (for testing/setup)
router.post("/seed", authMiddleware, requireAdmin, seedTemplate);

// Create template (only once, requires auth)
router.post("/", authMiddleware, requireAdmin, createTemplate);

// Get template (public or auth-protected based on requirements)
router.get("/", getTemplate);

// ========== CHECKLIST OPERATIONS ==========

// Add a checklist to a stage in the template
router.post(
  "/checklists",
  authMiddleware,
  requireAdmin,
  addChecklistToTemplate,
);

// Update a checklist in the template
router.patch(
  "/checklists/:checklistId",
  authMiddleware,
  requireAdmin,
  updateChecklistInTemplate,
);

// Delete a checklist from the template
router.delete(
  "/checklists/:checklistId",
  authMiddleware,
  requireAdmin,
  deleteChecklistFromTemplate,
);

// ========== CHECKPOINT OPERATIONS ==========

// Add a checkpoint to a checklist in the template (direct to group)
router.post(
  "/checklists/:checklistId/checkpoints",
  authMiddleware,
  requireAdmin,
  addCheckpointToTemplate,
);

// Add a checkpoint to a section in a checklist in the template
router.post(
  "/checklists/:checklistId/sections/:sectionId/checkpoints",
  authMiddleware,
  requireAdmin,
  addCheckpointToSection,
);

// Update a checkpoint inside a section in the template
router.patch(
  "/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  updateCheckpointInSection,
);

// Delete a checkpoint from a section in a checklist in the template
router.delete(
  "/checklists/:checklistId/sections/:sectionId/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromSection,
);

// Update a checkpoint in the template
router.patch(
  "/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  updateCheckpointInTemplate,
);

// Delete a checkpoint from the template
router.delete(
  "/checkpoints/:checkpointId",
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromTemplate,
);

// ========== SECTION OPERATIONS ==========

// Add a section to a checklist group in the template
router.post(
  "/checklists/:checklistId/sections",
  authMiddleware,
  requireAdmin,
  addSectionToChecklist,
);

// Update a section in a checklist group in the template
router.put(
  "/checklists/:checklistId/sections/:sectionId",
  authMiddleware,
  requireAdmin,
  updateSectionInChecklist,
);

// Delete a section from a checklist group in the template
router.delete(
  "/checklists/:checklistId/sections/:sectionId",
  authMiddleware,
  requireAdmin,
  deleteSectionFromChecklist,
);

// ========== DEFECT CATEGORY OPERATIONS ==========

// Update defect categories in the template
router.patch(
  "/defect-categories",
  authMiddleware,
  requireAdmin,
  updateDefectCategories,
);
// ========== STAGE OPERATIONS ==========

// Get all available stages
router.get("/stages", getTemplate);

// Add a new stage to the template
router.post("/stages", authMiddleware, requireAdmin, addStageToTemplate);

// Delete a stage from the template
router.delete("/stages/:stage", authMiddleware, requireAdmin, deleteStageFromTemplate);

// Reset template (delete all template data)
router.delete("/reset", authMiddleware, requireAdmin, resetTemplate);

export default router;
