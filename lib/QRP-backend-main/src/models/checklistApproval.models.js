import mongoose from 'mongoose';

const checklistApprovalSchema = new mongoose.Schema({
  project_id: { type: mongoose.Schema.Types.ObjectId, ref: 'Project', required: true, index: true },
  phase: { type: Number, required: true, min: 1, index: true },
  status: { type: String, enum: ['pending', 'approved', 'reverted'], default: 'pending' },
  requested_at: { type: Date, default: Date.now },
  decided_at: { type: Date },
  decided_by: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  notes: { type: String, default: '' },
  revertCount: { type: Number, default: 0, min: 0 }
}, { timestamps: true });

checklistApprovalSchema.index({ project_id: 1, phase: 1 }, { unique: true });

const ChecklistApproval = mongoose.model('ChecklistApproval', checklistApprovalSchema);
export default ChecklistApproval;
