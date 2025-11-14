import { Role } from '../models/roles.models.js';

// Get all roles
export const getAllRoles = async (req, res) => {
    try {
        const roles = await Role.find({}).sort({ role_name: 1 });
        res.status(200).json({
            success: true,
            data: roles
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Get role by ID
export const getRoleById = async (req, res) => {
    try {
        const role = await Role.findById(req.params.id);
        
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }
        
        res.status(200).json({
            success: true,
            data: role
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Create new role
export const createRole = async (req, res) => {
    try {
        const { role_name, description } = req.body;
        
        const role = await Role.create({
            role_name,
            description
        });
        
        res.status(201).json({
            success: true,
            data: role
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Update role
export const updateRole = async (req, res) => {
    try {
        const { role_name, description } = req.body;
        
        const role = await Role.findByIdAndUpdate(
            req.params.id,
            { role_name, description },
            { new: true }
        );
        
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }
        
        res.status(200).json({
            success: true,
            data: role
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// Delete role
export const deleteRole = async (req, res) => {
    try {
        const role = await Role.findByIdAndDelete(req.params.id);
        
        if (!role) {
            return res.status(404).json({
                success: false,
                message: 'Role not found'
            });
        }
        
        res.status(200).json({
            success: true,
            message: 'Role deleted successfully'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};