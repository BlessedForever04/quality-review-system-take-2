import mongoose from 'mongoose';

const projectSchema = new mongoose.Schema(
  {
    project_name: {
      type: String,
      required: true,
      trim: true
    },
    status: {
      type: String,
      enum: ['pending', 'in_progress', 'completed'],
      default: 'pending',
      required: true
    },
    start_date: {
      type: Date,
      required: true
    },
    end_date: {
      type: Date
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true
    }
  },
  {
    timestamps: true // adds createdAt and updatedAt automatically
  }
);

export default mongoose.model('Project', projectSchema);
