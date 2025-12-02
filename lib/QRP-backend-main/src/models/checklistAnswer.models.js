import mongoose from 'mongoose';

/**
 * ChecklistAnswer Model
 * Stores individual answers for checklist sub-questions per project, phase, and role.
 * Each document represents one sub-question's answer by a specific role (executor or reviewer).
 */
const checklistAnswerSchema = new mongoose.Schema({
    /**
     * The project this answer belongs to
     */
    project_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Project',
        required: true,
        index: true
    },

    /**
     * Phase number (e.g., 1 for Phase 1)
     */
    phase: {
        type: Number,
        required: true,
        min: 1
    },

    /**
     * Role of the person answering (executor or reviewer)
     */
    role: {
        type: String,
        required: true,
        enum: ['executor', 'reviewer'],
        lowercase: true
    },

    /**
     * The sub-question text (serves as the key)
     */
    sub_question: {
        type: String,
        required: true,
        trim: true
    },

    /**
     * The answer to the question (Yes/No/null)
     */
    answer: {
        type: String,
        enum: ['Yes', 'No', null],
        default: null
    },

    /**
     * Optional remark/comment
     */
    remark: {
        type: String,
        trim: true,
        default: ''
    },

    /**
     * Array of image file paths or URLs
     */
    images: {
        type: [String],
        default: []
    },

    /**
     * User who provided this answer
     */
    answered_by: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: false,
        default: null
    },

    /**
     * When this answer was last updated
     */
    answered_at: {
        type: Date,
        default: Date.now
    },

    /**
     * Whether this role has submitted their checklist
     * (Used to track if executor has submitted, allowing reviewer to view)
     */
    is_submitted: {
        type: Boolean,
        default: false
    }

}, {
    timestamps: true
});

// Compound index for efficient queries by project, phase, and role
checklistAnswerSchema.index({ project_id: 1, phase: 1, role: 1 });

// Unique constraint: one answer per project/phase/role/sub_question combination
checklistAnswerSchema.index(
    { project_id: 1, phase: 1, role: 1, sub_question: 1 }, 
    { unique: true }
);

const ChecklistAnswer = mongoose.model('ChecklistAnswer', checklistAnswerSchema);

export default ChecklistAnswer;
