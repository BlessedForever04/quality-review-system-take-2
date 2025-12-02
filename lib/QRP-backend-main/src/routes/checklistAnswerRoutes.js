import express from 'express';
// authMiddleware removed for unauthenticated checklist answer operations
// import authMiddleware from '../middleware/auth.Middleware.js';
import {
    getChecklistAnswers,
    saveChecklistAnswers,
    submitChecklistAnswers,
    getSubmissionStatus
} from '../controllers/checklistAnswer.controller.js';

const router = express.Router();

// Get checklist answers for a project/phase/role
router.get("/projects/:projectId/checklist-answers", getChecklistAnswers);

// Save/update checklist answers
router.put("/projects/:projectId/checklist-answers", saveChecklistAnswers);

// Submit checklist (mark as submitted)
router.post("/projects/:projectId/checklist-answers/submit", submitChecklistAnswers);

// Get submission status
router.get("/projects/:projectId/checklist-answers/submission-status", getSubmissionStatus);

export default router;
