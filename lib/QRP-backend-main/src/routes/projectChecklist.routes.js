import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import {
  getProjectChecklist,
  updateExecutorAnswer,
  updateReviewerStatus,
  getChecklistIterations,
  getDefectRatesPerIteration,
  getOverallDefectRate,
} from "../controllers/projectChecklist.controller.js";

const router = express.Router();

router.get(
  "/projects/:projectId/stages/:stageId/project-checklist",
  authMiddleware,
  getProjectChecklist,
);

router.get(
  "/projects/:projectId/stages/:stageId/project-checklist/iterations",
  authMiddleware,
  getChecklistIterations,
);

router.patch(
  "/projects/:projectId/stages/:stageId/checklist/groups/:groupId/questions/:questionId/executor",
  authMiddleware,
  updateExecutorAnswer,
);

router.patch(
  "/projects/:projectId/stages/:stageId/checklist/groups/:groupId/questions/:questionId/reviewer",
  authMiddleware,
  updateReviewerStatus,
);

router.get(
  "/projects/:projectId/defect-rates",
  authMiddleware,
  getDefectRatesPerIteration,
);

router.get(
  "/projects/:projectId/overall-defect-rate",
  authMiddleware,
  getOverallDefectRate,
);

export default router;
