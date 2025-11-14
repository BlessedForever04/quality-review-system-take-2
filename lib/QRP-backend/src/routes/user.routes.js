import express from "express";
import {
  registerUser,
  loginUser,
  logoutUser,
  getAllUsers
} from "../controllers/user.controller.js";
import { getUserProjects } from "../controllers/projectMembership.controller.js";
import authMiddleware from "../middleware/auth.Middleware.js";

const router = express.Router();

router.get("/", getAllUsers);                         // GET /api/v1/users
router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/logout", authMiddleware, logoutUser);

// User projects route
router.get("/:id/projects", getUserProjects);


export default router;
