import mongoose from 'mongoose';

const checklistTransactionSchema = new mongoose.Schema({
    /**
     * Links this log entry to the checklist it belongs to.
     */
    checklist_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Checklist',
        required: true,
        index: true // Makes searching by checklist_id fast
    },

    /**
     * The user who performed the action.
     */
    user_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },

    /**
     * The simple action code. This is the most important field.
     */
    action_type: {
        type: String,
        required: true,
        enum: [
            'CREATED',              // Checklist is made
            'SUBMITTED_FOR_REVIEW', // Executor -> Reviewer
            'CHANGES_REQUESTED',    // Reviewer -> Executor
            'APPROVED'              // Reviewer approves
        ]
    },
    
    /**
     * A human-readable sentence of what happened.
     * Example: "Jane Smith approved the checklist."
     */
    description: {
        type: String,
        required: true
    }
    
    // We have removed previous_status and new_status
    // The timestamp below is all you need.

}, {
    /**
     * This adds 'createdAt' automatically.
     * You can sort by this field to see the history in order.
     */
    timestamps: { createdAt: true, updatedAt: false }
});

const ChecklistHistory = mongoose.model('ChecklistHistory', checklistTransactionSchema);

export default ChecklistHistory;
