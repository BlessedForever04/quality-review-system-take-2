import mongoose from "mongoose";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import Checklist from "../models/checklist.models.js";
const createChecklistForStage = asyncHandler(async (req, res) => {
    const { stageId } = req.params;
    const { checklist_name, description, status } = req.body;
  
    if (!mongoose.isValidObjectId(stageId)) {
      throw new ApiError(400, "Invalid stageId");
    }
  
    if (!checklist_name?.trim()) {
      throw new ApiError(400, "checklist_name is required");
    }
  
    const created_by = req.user?._id;
    if (!created_by) {
      throw new ApiError(401, "Not authenticated");
    }
  
    const checklist = await Checklist.create({
      stage_id: stageId,
      created_by,
      checklist_name,
      description,
      status // optional; model defaults to 'draft'
    });
  
    return res
      .status(201)
      .json(new ApiResponse(201, checklist, "Checklist created successfully"));
  });
const listChecklistsForStage = asyncHandler(async (req, res) => {
  const { stageId } = req.params;

  if (!mongoose.isValidObjectId(stageId)) {
    throw new ApiError(400, "Invalid stageId");
  }

  const checklists = await Checklist.find({ stage_id: stageId }).sort({ createdAt: 1 });

  return res
    .status(200)
    .json(new ApiResponse(200, checklists, "Checklists fetched successfully"));
});
const getChecklistById = asyncHandler(async (req, res) => {
    const { id } = req.params
  
    if (!mongoose.isValidObjectId(id)) {
      throw new ApiError(400, "Invalid checklist id")
    }
  
    const checklist = await Checklist.findById(id)
    if (!checklist) {
      throw new ApiError(404, "Checklist not found")
    }
  
    return res
      .status(200)
      .json(new ApiResponse(200, checklist, "Checklist fetched successfully"))
  });
  const updateChecklist = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const { checklist_name, description, status } = req.body;
  
    if (!mongoose.isValidObjectId(id)) {
      throw new ApiError(400, "Invalid checklist id");
    }
  
    // Only allow updating permitted fields
    const update = {};
    if (typeof checklist_name === "string") update.checklist_name = checklist_name;
    if (typeof description === "string") update.description = description;
    if (typeof status === "string") update.status = status; // enum validated by model
  
    if (Object.keys(update).length === 0) {
      throw new ApiError(400, "No valid fields provided to update");
    }
  
    const checklist = await Checklist.findByIdAndUpdate(
      id,
      { $set: update },
      { new: true, runValidators: true }
    );
  
    if (!checklist) {
      throw new ApiError(404, "Checklist not found");
    }
  
    return res
      .status(200)
      .json(new ApiResponse(200, checklist, "Checklist updated successfully"));
  });
  const deleteChecklist = asyncHandler(async (req, res) => {
    const { id } = req.params;
  
    if (!mongoose.isValidObjectId(id)) {
      throw new ApiError(400, "Invalid checklist id");
    }
  
    const deleted = await Checklist.findByIdAndDelete(id);
    if (!deleted) {
      throw new ApiError(404, "Checklist not found");
    }
  
    return res
      .status(200)
      .json(new ApiResponse(200, deleted, "Checklist deleted successfully"));
  });
  const submitChecklist = async (req, res) => {
    try {
      const checklistId = req.params.id;
      const userId = req.body.user_id;
  
      const checklist = await Checklist.findById(checklistId);
      if (!checklist) return res.status(404).json({ message: 'Checklist not found' });
  
      checklist.status = 'pending';
      checklist.revision_number += 1;
      await checklist.save();
  
      await ChecklistHistory.create({
        checklist_id: checklist._id,
        user_id: userId,
        action_type: 'SUBMITTED_FOR_REVIEW',
        description: `Checklist "${checklist.checklist_name}" was submitted for review.`
      });
  
      res.status(200).json({ message: 'Checklist submitted for review successfully', checklist });
    } catch (err) {
      res.status(500).json({ message: 'Error submitting checklist', error: err.message });
    }
  };
  
  /**
   * POST /api/checklists/:id/approve
   * Marks checklist as "approved" and logs the action.
   */
  const approveChecklist = async (req, res) => {
    try {
      const checklistId = req.params.id;
      const userId = req.body.user_id;
  
      const checklist = await Checklist.findById(checklistId);
      if (!checklist) return res.status(404).json({ message: 'Checklist not found' });
  
      checklist.status = 'approved';
      await checklist.save();
  
      await ChecklistHistory.create({
        checklist_id: checklist._id,
        user_id: userId,
        action_type: 'APPROVED',
        description: `Checklist "${checklist.checklist_name}" was approved.`
      });
  
      res.status(200).json({ message: 'Checklist approved successfully', checklist });
    } catch (err) {
      res.status(500).json({ message: 'Error approving checklist', error: err.message });
    }
  };
  
  /**
   * POST /api/checklists/:id/request-changes
   * Marks checklist as "changes_requested" and logs the action.
   */
  const requestChanges = async (req, res) => {
    try {
      const checklistId = req.params.id;
      const userId = req.body.user_id;
      const { message } = req.body;
  
      const checklist = await Checklist.findById(checklistId);
      if (!checklist) return res.status(404).json({ message: 'Checklist not found' });
  
      checklist.status = 'changes_requested';
      await checklist.save();
  
      await ChecklistHistory.create({
        checklist_id: checklist._id,
        user_id: userId,
        action_type: 'CHANGES_REQUESTED',
        description: message || `Changes were requested for checklist "${checklist.checklist_name}".`
      });
  
      res.status(200).json({ message: 'Changes requested successfully', checklist });
    } catch (err) {
      res.status(500).json({ message: 'Error requesting changes', error: err.message });
    }
  };
  
  /**
   * GET /api/checklists/:id/history
   * Fetches the full audit history of a checklist.
   */
  const getChecklistHistory = async (req, res) => {
    try {
      const checklistId = req.params.id;
  
      const history = await ChecklistHistory.find({ checklist_id: checklistId })
        .populate('user_id', 'name email') // populate user info if available
        .sort({ createdAt: 1 });
  
      if (!history.length) {
        return res.status(404).json({ message: 'No history found for this checklist' });
      }
  
      res.status(200).json({ history });
    } catch (err) {
      res.status(500).json({ message: 'Error fetching checklist history', error: err.message });
    }
  };
  export { listChecklistsForStage, getChecklistById ,createChecklistForStage,updateChecklist,deleteChecklist,approveChecklist,submitChecklist,requestChanges,getChecklistHistory};