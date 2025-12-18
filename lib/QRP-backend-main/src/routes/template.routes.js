import express from 'express';
import authMiddleware from '../middleware/auth.Middleware.js';
import { requireAdmin } from '../middleware/role.middleware.js';
import {
  createTemplate,
  getTemplate,
  addChecklistToTemplate,
  updateChecklistInTemplate,
  deleteChecklistFromTemplate,
  addCheckpointToTemplate,
  updateCheckpointInTemplate,
  deleteCheckpointFromTemplate,
} from '../controllers/template.controller.js';

const router = express.Router();

/**
 * TEMPLATE ROUTES
 * Base path: /api/v1/templates
 * 
 * Note: Only ONE template exists in the system
 */

// Create template (only once, requires auth)
router.post(
  '/',
  authMiddleware,
  requireAdmin,
  createTemplate
);

// Get template (public or auth-protected based on requirements)
router.get(
  '/',
  getTemplate
);

// ========== CHECKLIST OPERATIONS ==========

// Add a checklist to a stage in the template
router.post(
  '/checklists',
  authMiddleware,
  requireAdmin,
  addChecklistToTemplate
);

// Update a checklist in the template
router.patch(
  '/checklists/:checklistId',
  authMiddleware,
  requireAdmin,
  updateChecklistInTemplate
);

// Delete a checklist from the template
router.delete(
  '/checklists/:checklistId',
  authMiddleware,
  requireAdmin,
  deleteChecklistFromTemplate
);

// ========== CHECKPOINT OPERATIONS ==========

// Add a checkpoint to a checklist in the template
router.post(
  '/checklists/:checklistId/checkpoints',
  authMiddleware,
  requireAdmin,
  addCheckpointToTemplate
);

// Update a checkpoint in the template
router.patch(
  '/checkpoints/:checkpointId',
  authMiddleware,
  requireAdmin,
  updateCheckpointInTemplate
);

// Delete a checkpoint from the template
router.delete(
  '/checkpoints/:checkpointId',
  authMiddleware,
  requireAdmin,
  deleteCheckpointFromTemplate
);

export default router;
