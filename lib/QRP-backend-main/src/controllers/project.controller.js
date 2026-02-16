import Project from "../models/project.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import Template from "../models/template.models.js";
import Stage from "../models/stage.models.js";
import Checklist from "../models/checklist.models.js";
import Checkpoint from "../models/checkpoint.models.js";
import ProjectChecklist from "../models/projectChecklist.models.js";
import ChecklistAnswer from "../models/checklistAnswer.models.js";
import ChecklistApproval from "../models/checklistApproval.models.js";
import ChecklistTransaction from "../models/checklistTransaction.models.js";
import { deleteImagesByFileIds } from "../gridfs.js";

// Helper function to sync existing checkpoints with template categories
async function syncCheckpointsWithTemplate(projectId) {
  try {
    const template = await Template.findOne();
    if (!template) return;

    const stages = await Stage.find({ project_id: projectId });

    // Dynamically derive stage key from stage name (handles any phase number)
    const deriveStageKeyFromName = (stageName) => {
      const match = stageName
        .toLowerCase()
        .match(/(?:phase|stage)\s*(\d{1,2})/);
      return match ? `stage${parseInt(match[1])}` : null;
    };

    for (const stage of stages) {
      const templateStageKey = deriveStageKeyFromName(stage.stage_name);
      if (!templateStageKey) continue;

      const templateChecklists = template[templateStageKey] || [];
      const checklists = await Checklist.find({ stage_id: stage._id });

      for (const checklist of checklists) {
        const templateChecklist = templateChecklists.find(
          (tc) => tc.text === checklist.checklist_name,
        );
        if (!templateChecklist) continue;

        for (const checkpoint of checklist.checkpoints || []) {
          const templateCheckpoint = templateChecklist.checkpoints?.find(
            (tcp) => tcp.text === checkpoint.question,
          );
          if (templateCheckpoint?.categoryId) {
            await Checkpoint.updateOne(
              { _id: checkpoint._id },
              { categoryId: templateCheckpoint.categoryId },
            );
          }
        }
      }
    }
  } catch (error) {
    // Don't throw - let project creation succeed even if template sync fails
  }
}

// Get all projects
export const getAllProjects = async (req, res) => {
  try {
    const projects = await Project.find({})
      .populate("created_by", "name email")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      data: projects,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get projects for a specific user (optimized endpoint with pre-populated memberships)
export const getProjectsForUser = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: "User ID is required",
      });
    }

    // Find all project memberships for this user
    const memberships = await ProjectMembership.find({ user_id: userId })
      .populate({
        path: "project_id",
        populate: { path: "created_by", select: "name email" },
      })
      .populate("role", "role_name");

    // Extract unique project IDs
    const projectIds = memberships
      .filter((m) => m.project_id)
      .map((m) => m.project_id._id);

    // Get all memberships for these projects to build complete member lists
    const allMemberships = await ProjectMembership.find({
      project_id: { $in: projectIds },
    }).populate("role", "role_name");

    // Build a map of project_id -> array of member user_ids
    const projectMembersMap = {};
    for (const m of allMemberships) {
      const pid = m.project_id.toString();
      if (!projectMembersMap[pid]) {
        projectMembersMap[pid] = [];
      }
      projectMembersMap[pid].push(m.user_id);
    }

    // Extract projects and attach membership info
    const projectsWithMemberships = memberships
      .filter((m) => m.project_id) // Filter out invalid project references
      .map((m) => {
        const project = m.project_id.toObject();
        const pid = project._id.toString();
        return {
          ...project,
          userRole: m.role?.role_name || null,
          membershipId: m._id,
          assignedEmployees: projectMembersMap[pid] || [],
        };
      });

    res.status(200).json({
      success: true,
      data: projectsWithMemberships,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get project by ID
export const getProjectById = async (req, res) => {
  try {
    const project = await Project.findById(req.params.id).populate(
      "created_by",
      "name email",
    );

    if (!project) {
      return res.status(404).json({
        success: false,
        message: "Project not found",
      });
    }

    res.status(200).json({
      success: true,
      data: project,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Create new project
export const createProject = async (req, res) => {
  try {
    const {
      project_no,
      internal_order_no,
      project_name,
      description,
      status,
      priority,
      start_date,
      end_date,
      created_by,
      isReviewApplicable,
    } = req.body;

    // Prefer authenticated user as creator
    const creatorId = req.user?._id || created_by;

    const project = await Project.create({
      project_no,
      internal_order_no,
      project_name,
      description,
      status,
      priority,
      start_date,
      end_date,
      created_by: creatorId,
      isReviewApplicable,
    });

    // Note: Stages and checklists are created when project is started
    // (status changes from 'pending' to 'in_progress' in updateProject)

    // Populate the created project
    const populatedProject = await Project.findById(project._id).populate(
      "created_by",
      "name email",
    );

    res.status(201).json({
      success: true,
      data: populatedProject,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

/**
 * Helper: Create stages and project checklists from template
 * Called automatically when a project is created
 */
async function createStagesAndChecklistsFromTemplate(projectId) {
  try {
    const template = await Template.findOne();
    if (!template) {
      return;
    }

    // Get all stage keys from template (stage1, stage2, stage3, etc.)
    const stageKeys = Object.keys(template.toObject())
      .filter((key) => /^stage\d{1,2}$/.test(key))
      .sort((a, b) => {
        const numA = parseInt(a.replace("stage", ""));
        const numB = parseInt(b.replace("stage", ""));
        return numA - numB;
      });

    const stageNames = template.stageNames || {};

    // Create a stage for each template stage
    for (const stageKey of stageKeys) {
      const stageNum = parseInt(stageKey.replace("stage", ""));
      const stageName = stageNames[stageKey] || `Phase ${stageNum}`;

      // Create stage
      const stage = await Stage.create({
        project_id: projectId,
        stage_name: stageName,
        stage_key: stageKey,
        status: "pending",
      });

      // Get checklist groups from template stage
      const templateGroups = template[stageKey] || [];

      // Create project checklist
      const groups = templateGroups.map((templateGroup) => ({
        groupName: templateGroup.text,
        questions: (templateGroup.checkpoints || []).map((cp) => ({
          text: cp.text,
          executorAnswer: null,
          executorRemark: "",
          reviewerStatus: null,
          reviewerRemark: "",
        })),
        sections: (templateGroup.sections || []).map((section) => ({
          sectionName: section.text,
          questions: (section.checkpoints || []).map((cp) => ({
            text: cp.text,
            executorAnswer: null,
            executorRemark: "",
            reviewerStatus: null,
            reviewerRemark: "",
          })),
        })),
      }));

      const projectChecklist = await ProjectChecklist.create({
        projectId,
        stageId: stage._id,
        stage: stageKey,
        groups,
      });
    }
  } catch (error) {
    // Don't throw - let project creation succeed even if template sync fails
  }
}

// Update project
export const updateProject = async (req, res) => {
  try {
    const {
      project_no,
      internal_order_no,
      project_name,
      description,
      status,
      priority,
      start_date,
      end_date,
      isReviewApplicable,
    } = req.body;

    const existing = await Project.findById(req.params.id);
    if (!existing) {
      return res
        .status(404)
        .json({ success: false, message: "Project not found" });
    }

    const prevStatus = existing.status;

    // Guard: only assigned users may start the project
    const requestedStatus =
      typeof status === "string" ? status : existing.status;
    if (prevStatus === "pending" && requestedStatus === "in_progress") {
      const assigned = await ProjectMembership.findOne({
        project_id: existing._id,
        user_id: req.user?._id,
      });
      if (!assigned) {
        return res.status(403).json({
          success: false,
          message: "Only assigned users can start this project",
        });
      }
    }

    // Perform update
    existing.project_no = project_no ?? existing.project_no;
    existing.internal_order_no =
      internal_order_no ?? existing.internal_order_no;
    if (typeof project_name === "string") existing.project_name = project_name;
    if (typeof description === "string") existing.description = description;
    if (typeof status === "string") existing.status = status;
    if (typeof priority === "string") existing.priority = priority;
    if (start_date) existing.start_date = start_date;
    if (end_date) existing.end_date = end_date;
    if (typeof isReviewApplicable === "boolean")
      existing.isReviewApplicable = isReviewApplicable;
    await existing.save();

    const project = await Project.findById(existing._id).populate(
      "created_by",
      "name email",
    );

    // If status changed from pending -> in_progress, assign template to this project
    if (prevStatus === "pending" && existing.status === "in_progress") {
      const existingStagesCount = await Stage.countDocuments({
        project_id: existing._id,
      });

      if (existingStagesCount === 0) {
        // Use the helper function to create stages and checklists
        await createStagesAndChecklistsFromTemplate(existing._id);
      }
    }

    res.status(200).json({ success: true, data: project });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Sync existing checkpoints with template categories
export const syncCheckpointCategories = async (req, res) => {
  try {
    const { projectId } = req.params;
    await syncCheckpointsWithTemplate(projectId);
    res.status(200).json({
      success: true,
      message: "Checkpoints synced with template categories",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Get all stages for a project with their names
export const getProjectStages = async (req, res) => {
  try {
    const { projectId } = req.params;

    const stages = await Stage.find({ project_id: projectId }).sort({
      createdAt: 1,
    });

    if (!stages || stages.length === 0) {
      return res.status(200).json({
        success: true,
        data: [],
        message: "No stages found for this project",
      });
    }

    const stageData = stages.map((stage) => ({
      _id: stage._id,
      stage_name: stage.stage_name,
      stage_key: stage.stage_key,
      status: stage.status,
      loopback_count: stage.loopback_count || 0,
      conflict_count: stage.conflict_count || 0,
    }));

    res.status(200).json({
      success: true,
      data: stageData,
      message: "Project stages fetched successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// Delete project
export const deleteProject = async (req, res) => {
  try {
    const projectId = req.params.id;
    const project = await Project.findById(projectId);

    if (!project) {
      return res.status(404).json({
        success: false,
        message: "Project not found",
      });
    }

    // Cascade delete: Remove all related data
    const deletionStats = {};

    // 1. Delete project memberships
    const deletedMemberships = await ProjectMembership.deleteMany({
      project_id: projectId,
    });
    deletionStats.memberships = deletedMemberships.deletedCount;

    // 2. Delete checklist answers
    const deletedAnswers = await ChecklistAnswer.deleteMany({
      project_id: projectId,
    });
    deletionStats.checklistAnswers = deletedAnswers.deletedCount;

    // 3. Delete checklist approvals (TeamLeader approvals)
    const deletedApprovals = await ChecklistApproval.deleteMany({
      project_id: projectId,
    });
    deletionStats.checklistApprovals = deletedApprovals.deletedCount;

    // 4. Collect and delete all images associated with this project (BEFORE deleting checklists)
    try {
      const projectChecklists = await ProjectChecklist.find({
        projectId: projectId,
      });
      const allFileIds = [];

      // Collect all fileIds from executor and reviewer images in all questions
      for (const checklist of projectChecklists) {
        for (const group of checklist.groups || []) {
          // Direct questions in group
          for (const question of group.questions || []) {
            allFileIds.push(
              ...(question.executorImages?.map((img) => img.fileId) || []),
            );
            allFileIds.push(
              ...(question.reviewerImages?.map((img) => img.fileId) || []),
            );
          }
          // Questions in sections
          for (const section of group.sections || []) {
            for (const question of section.questions || []) {
              allFileIds.push(
                ...(question.executorImages?.map((img) => img.fileId) || []),
              );
              allFileIds.push(
                ...(question.reviewerImages?.map((img) => img.fileId) || []),
              );
            }
          }
        }
        // Also check iterations
        for (const iteration of checklist.iterations || []) {
          for (const group of iteration.groups || []) {
            for (const question of group.questions || []) {
              allFileIds.push(
                ...(question.executorImages?.map((img) => img.fileId) || []),
              );
              allFileIds.push(
                ...(question.reviewerImages?.map((img) => img.fileId) || []),
              );
            }
            for (const section of group.sections || []) {
              for (const question of section.questions || []) {
                allFileIds.push(
                  ...(question.executorImages?.map((img) => img.fileId) || []),
                );
                allFileIds.push(
                  ...(question.reviewerImages?.map((img) => img.fileId) || []),
                );
              }
            }
          }
        }
      }

      // Remove duplicates and delete all images
      const uniqueFileIds = [...new Set(allFileIds.filter((id) => id))];
      if (uniqueFileIds.length > 0) {
        await deleteImagesByFileIds(uniqueFileIds);
        deletionStats.imagesDeleted = uniqueFileIds.length;
      }
    } catch (imageError) {
      deletionStats.imagesDeleteError = imageError.message;
    }

    // 5. Delete project checklists
    const deletedProjectChecklists = await ProjectChecklist.deleteMany({
      projectId: projectId,
    });
    deletionStats.projectChecklists = deletedProjectChecklists.deletedCount;

    // 6. Find all stages for this project
    const stages = await Stage.find({ project_id: projectId });
    const stageIds = stages.map((stage) => stage._id);
    deletionStats.stages = stages.length;

    // 7. Find all checklists for these stages
    const checklists = await Checklist.find({ stage_id: { $in: stageIds } });
    const checklistIds = checklists.map((checklist) => checklist._id);

    // 8. Delete checkpoints for these checklists
    const deletedCheckpoints = await Checkpoint.deleteMany({
      checklistId: { $in: checklistIds },
    });
    deletionStats.checkpoints = deletedCheckpoints.deletedCount;

    // 9. Delete checklist transactions for these checklists
    const deletedTransactions = await ChecklistTransaction.deleteMany({
      checklist_id: { $in: checklistIds },
    });
    deletionStats.checklistTransactions = deletedTransactions.deletedCount;

    // 10. Delete the checklists themselves
    const deletedChecklists = await Checklist.deleteMany({
      stage_id: { $in: stageIds },
    });
    deletionStats.checklists = deletedChecklists.deletedCount;

    // 11. Delete the stages
    const deletedStages = await Stage.deleteMany({ project_id: projectId });
    deletionStats.stagesDeleted = deletedStages.deletedCount;

    // 12. Finally, delete the project itself
    await Project.findByIdAndDelete(projectId);

    res.status(200).json({
      success: true,
      message: "Project and all related data deleted successfully",
      deletionStats,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
