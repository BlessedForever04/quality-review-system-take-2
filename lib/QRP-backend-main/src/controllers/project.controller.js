import Project from '../models/project.models.js';
import ProjectMembership from '../models/projectMembership.models.js';
import Template from '../models/template.models.js';
import Stage from '../models/stage.models.js';
import Checklist from '../models/checklist.models.js';
import Checkpoint from '../models/checkpoint.models.js';

// Get all projects
export const getAllProjects = async (req, res) => {
    try {
        const projects = await Project.find({})
            .populate('created_by', 'name email')
            .sort({ createdAt: -1 });
        
        res.status(200).json({
            success: true,
            data: projects
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Get project by ID
export const getProjectById = async (req, res) => {
    try {
        const project = await Project.findById(req.params.id)
            .populate('created_by', 'name email');
        
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Project not found'
            });
        }
        
        res.status(200).json({
            success: true,
            data: project
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Create new project
export const createProject = async (req, res) => {
    try {
        const { project_no, internal_order_no, project_name, description, status, priority, start_date, end_date, created_by } = req.body;

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
            created_by: creatorId
        });

        // Populate the created project
        const populatedProject = await Project.findById(project._id)
            .populate('created_by', 'name email');

        res.status(201).json({
            success: true,
            data: populatedProject
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Update project
export const updateProject = async (req, res) => {
    try {
        const { project_no, internal_order_no, project_name, description, status, priority, start_date, end_date } = req.body;

        const existing = await Project.findById(req.params.id);
        if (!existing) {
            return res.status(404).json({ success: false, message: 'Project not found' });
        }

        const prevStatus = existing.status;

        // Guard: only assigned users may start the project
        const requestedStatus = typeof status === 'string' ? status : existing.status;
        if (prevStatus === 'pending' && requestedStatus === 'in_progress') {
            const assigned = await ProjectMembership.findOne({ project_id: existing._id, user_id: req.user?._id });
            if (!assigned) {
                return res.status(403).json({ success: false, message: 'Only assigned users can start this project' });
            }
        }

        // Perform update
        existing.project_no = project_no ?? existing.project_no;
        existing.internal_order_no = internal_order_no ?? existing.internal_order_no;
        if (typeof project_name === 'string') existing.project_name = project_name;
        if (typeof description === 'string') existing.description = description;
        if (typeof status === 'string') existing.status = status;
        if (typeof priority === 'string') existing.priority = priority;
        if (start_date) existing.start_date = start_date;
        if (end_date) existing.end_date = end_date;
        await existing.save();

        const project = await Project.findById(existing._id).populate('created_by', 'name email');

        // If status changed from pending -> in_progress, assign template to this project
        if (prevStatus === 'pending' && existing.status === 'in_progress') {
            const existingStagesCount = await Stage.countDocuments({ project_id: existing._id });
            if (existingStagesCount === 0) {
                const template = await Template.findOne();
                if (template) {
                    const creatorId = req.user?._id || project.created_by?._id;
                    const stageDefs = [
                        { name: 'Phase 1', key: 'stage1' },
                        { name: 'Phase 2', key: 'stage2' },
                        { name: 'Phase 3', key: 'stage3' },
                    ];

                    const stageDocs = [];
                    for (const def of stageDefs) {
                        const stage = await Stage.create({
                            project_id: existing._id,
                            stage_name: def.name,
                            status: 'pending',
                            created_by: creatorId,
                        });
                        stageDocs.push({ doc: stage, key: def.key });
                    }

                    for (const { doc: stage, key } of stageDocs) {
                        const checklists = template[key] || [];
                        for (const cl of checklists) {
                            const checklist = await Checklist.create({
                                stage_id: stage._id,
                                created_by: creatorId,
                                checklist_name: cl.text,
                                description: '',
                                status: 'draft',
                                revision_number: 0,
                                answers: {},
                            });

                            const cps = cl.checkpoints || [];
                            for (const cp of cps) {
                                await Checkpoint.create({
                                    checklistId: checklist._id,
                                    question: cp.text,
                                    executorResponse: {},
                                    reviewerResponse: {},
                                });
                            }
                        }
                    }
                }
            }
        }

        res.status(200).json({ success: true, data: project });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Delete project
export const deleteProject = async (req, res) => {
    try {
        const project = await Project.findByIdAndDelete(req.params.id);
        
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Project not found'
            });
        }
        
        // Cascade delete: Remove all project memberships associated with this project
        const deletedMemberships = await ProjectMembership.deleteMany({ project_id: req.params.id });
        console.log(`[Project Delete] Removed ${deletedMemberships.deletedCount} membership(s) for project ${req.params.id}`);
        
        res.status(200).json({
            success: true,
            message: 'Project deleted successfully',
            deletedMemberships: deletedMemberships.deletedCount
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};