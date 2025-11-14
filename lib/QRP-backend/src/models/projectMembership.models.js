import mongoose from 'mongoose';

const projectMembershipSchema = new mongoose.Schema({
    /**
     * Links to the project document.
     */
    project_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Project',
        required: true
    },

    /**
     * Links to the user document.
     */
    user_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },

    /**
     * This is the link to the 'Role' document's _id.
     * This 'ref' allows you to use .populate()
     */
    role: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Role', // This tells Mongoose to link to the 'Role' model
        required: true
    }
}, {
    timestamps: { createdAt: true, updatedAt: false }
});

/**
 * This flexible index prevents adding the exact same user
 * to the exact same project with the exact same role twice.
 */
projectMembershipSchema.index({ project_id: 1, user_id: 1, role: 1 }, { unique: true });

const ProjectMembership = mongoose.model('ProjectMembership', projectMembershipSchema);

export default ProjectMembership;
