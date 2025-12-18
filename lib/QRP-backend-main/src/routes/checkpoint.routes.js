import express from 'express';
import authMiddleware from '../middleware/auth.Middleware.js';
import {
  createCheckpoint,
  getCheckpointsByChecklistId,
  getCheckpointById,
  updateCheckpointResponse,
  deleteCheckpoint,
} from '../controllers/checkpoint.controller.js';

const router = express.Router();

/**
 * CHECKPOINT ROUTES
 * Base path: /api/v1
 */

// Get all checkpoints for a specific checklist
router.get(
  '/checklists/:checklistId/checkpoints',
  getCheckpointsByChecklistId
);

// Create a new checkpoint for a checklist (auth required)
router.post(
  '/checklists/:checklistId/checkpoints',
  authMiddleware,
  createCheckpoint
);

// Get a specific checkpoint by ID
router.get(
  '/checkpoints/:checkpointId',
  getCheckpointById
);

// Update checkpoint response (with optional images via multipart)
// Note: If using multer for image uploads, add middleware here
router.patch(
  '/checkpoints/:checkpointId',
  authMiddleware,
  // upload.array("images", 5), // Uncomment if using multer
  updateCheckpointResponse
);

// Delete a checkpoint (auth required)
router.delete(
  '/checkpoints/:checkpointId',
  authMiddleware,
  deleteCheckpoint
);

export default router;
