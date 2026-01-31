import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import {
  getStageById,
  updateStage,
  deleteStage,
  listStagesForProject,
  createStage,
  migrateStageCounters,
} from "../controllers/stage.controller.js";

const router = express.Router();

router.get("/stages/:id", getStageById);
router.put("/stages/:id", updateStage);
router.delete("/stages/:id", deleteStage);

// Migration endpoint to add counter fields to existing stages (no auth for admin use)
router.post("/stages/migrate-counters", migrateStageCounters);

// Moved from project.routes.js:
// GET/POST /api/v1/projects/:projectId/stages (protected)
router.get("/projects/:projectId/stages", authMiddleware, listStagesForProject);
router.post("/projects/:projectId/stages", authMiddleware, createStage);

export default router;
