import { ApiError } from "../utils/ApiError.js";

export const requireAdmin = (req, _, next) => {
  try {
    if (!req.user || req.user.role !== "admin") {
      throw new ApiError(403, "Admin access required");
    }
    next();
  } catch (error) {
    next(error);
  }
};
