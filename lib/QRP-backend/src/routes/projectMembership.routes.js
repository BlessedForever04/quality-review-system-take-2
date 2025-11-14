import express from "express";
import {
  getProjectMembers,
  addProjectMember,
  updateProjectMember,
  removeProjectMember
} from "../controllers/projectMembership.controller.js";

const router = express.Router();

// Project membership routes
router.get("/members", getProjectMembers);           // GET /api/v1/projects/members
router.post("/members", addProjectMember);           // POST /api/v1/projects/members  
router.put("/members", updateProjectMember);         // PUT /api/v1/projects/members
router.delete("/members", removeProjectMember);      // DELETE /api/v1/projects/members

export default router;