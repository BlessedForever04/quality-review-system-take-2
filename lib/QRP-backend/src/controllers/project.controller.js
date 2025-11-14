import Project from '../models/project.models.js';

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
        const { project_name, status, start_date, end_date, created_by } = req.body;
        
        const project = await Project.create({
            project_name,
            status,
            start_date,
            end_date,
            created_by
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
        const { project_name, status, start_date, end_date } = req.body;
        
        const project = await Project.findByIdAndUpdate(
            req.params.id,
            { project_name, status, start_date, end_date },
            { new: true }
        ).populate('created_by', 'name email');
        
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
        
        res.status(200).json({
            success: true,
            message: 'Project deleted successfully'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};