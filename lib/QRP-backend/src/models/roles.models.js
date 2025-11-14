import mongoose from 'mongoose';

const roleSchema = new mongoose.Schema(
  {
    /**
     * The name of the role. We make this unique.
     * e.g., "Executor", "Reviewer", "SDH"
     */
    role_name: {
      type: String,
      required: true,
      unique: true, // This is the important part
      trim: true
    },
    description: {
      type: String,
      trim: true
    },
  },
  { timestamps: true }
);
// We let Mongoose use the default '_id'

export const Role = mongoose.model("Role", roleSchema);