import mongoose from 'mongoose';

const checklistSchema = new mongoose.Schema({
    /**
     * Answer 1: Belongs to a Stage.
     * This links the checklist to its parent stage.
     */
    stage_id: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Stage',
        required: true
    },

    /**
     * Answer 2: Save who created it.
     * This stores the User ID of the person who made the checklist.
     */
    created_by: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },

    /**
     * Answer 3: Track the status.
     * This is the "dropdown" to track the review loop.
     */
    status: {
        type: String,
        required: true,
        enum: ['draft', 'pending', 'approved', 'changes_requested'],
        default: 'draft'
    },

    /**
     * Answer 4: Count the review submissions.
     * This number will be 0, then 1, then 2, etc.
     */
    revision_number: {
        type: Number,
        required: true,
        default: 0
    },
    
    // --- Other Basic Fields ---
    
    /**
     * The name of the checklist (e.g., "Electrical Safety Checks").
     */
    checklist_name: {
        type: String,
        required: true,
        trim: true
    },
    
    /**
     * An optional description for more details.
     */
    description: {
        type: String,
        trim: true
    }

}, {
    /**
     * This automatically adds 'createdAt' and 'updatedAt' fields
     * so you know when it was made and last changed.
     */
    timestamps: true
});

const Checklist = mongoose.model('Checklist', checklistSchema);

export default Checklist;
