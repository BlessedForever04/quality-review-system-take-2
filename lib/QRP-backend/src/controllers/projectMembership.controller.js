import ProjectMembership from '../models/projectMembership.models.js';
import Project from '../models/project.models.js';
import { User } from '../models/user.models.js';
import { Role } from '../models/roles.models.js';

// GET /api/v1/projects/members - Get project members
export const getProjectMembers = async (req, res) => {
    try {
        const { project_id } = req.body;
        
        // Check if project exists
        const project = await Project.findById(project_id);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Project not found'
            });
        }

        const members = await ProjectMembership.find({ project_id: project_id })
            .populate('user_id', 'name email role')
            .populate('role', 'role_name description');

        res.status(200).json({
            success: true,
            data: {
                project: project.project_name,
                members: members
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// POST /api/v1/projects/members - Add member to project
export const addProjectMember = async (req, res) => {
    try {
        const { project_id, user_id, role_id } = req.body;

        // Check if project exists
        const project = await Project.findById(project_id);
        if (!project) {
            return res.status(404).json({
                success: false,
                message: 'Project not found'
            });
        }

        // Check if user exists
        const user = await User.findById(user_id);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        // Check if role exists
        const role = await Role.findById(role_id);
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }

        const membership = await ProjectMembership.create({
            project_id: project_id,
            user_id: user_id,
            role: role_id
        });

        const populatedMembership = await ProjectMembership.findById(membership._id)
            .populate('user_id', 'name email')
            .populate('role', 'role_name description');

        res.status(201).json({
            success: true,
            data: populatedMembership
        });
    } catch (error) {
        // Handle duplicate key error
        if (error.code === 11000) {
            return res.status(409).json({
                success: false,
                message: 'User already has this role in the project'
            });
        }
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// PUT /api/v1/projects/members - Update member role
export const updateProjectMember = async (req, res) => {
    try {
        const { project_id, user_id, role_id } = req.body;

        // Check if role exists
        const role = await Role.findById(role_id);
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }

        const membership = await ProjectMembership.findOneAndUpdate(
            { project_id: project_id, user_id: user_id },
            { role: role_id },
            { new: true }
        )
        .populate('user_id', 'name email')
        .populate('role', 'role_name description');

        if (!membership) {
            return res.status(404).json({
                success: false,
                message: 'Project membership not found'
            });
        }

        res.status(200).json({
            success: true,
            data: membership
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// DELETE /api/v1/projects/members - Remove member from project
export const removeProjectMember = async (req, res) => {
    try {
        const { project_id, user_id } = req.body;

        const membership = await ProjectMembership.findOneAndDelete({
            project_id: project_id,
            user_id: user_id
        });

        if (!membership) {
            return res.status(404).json({
                success: false,
                message: 'Project membership not found'
            });
        }

        res.status(200).json({
            success: true,
            message: 'Member removed from project successfully'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// GET /api/v1/users/:id/projects - Get all projects for a user
export const getUserProjects = async (req, res) => {
    try {
        const { id } = req.params; // user id

        // Check if user exists
        const user = await User.findById(id);
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const projects = await ProjectMembership.find({ user_id: id })
            .populate('project_id', 'project_name status start_date end_date')
            .populate('role', 'role_name description');

        res.status(200).json({
            success: true,
            data: {
                user: user.name,
                projects: projects
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};