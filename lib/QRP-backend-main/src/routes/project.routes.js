import express from "express";
import authMiddleware from "../middleware/auth.Middleware.js";
import {
  getAllProjects,
  getProjectById,
  createProject,
  updateProject,
  deleteProject
} from "../controllers/project.controller.js";

const router = express.Router();

router.get("/", getAllProjects);
router.get("/:id", getProjectById);
router.post("/", authMiddleware, createProject);
router.put("/:id", authMiddleware, updateProject);
router.delete("/:id", authMiddleware, deleteProject);

export default router;