import jwt from "jsonwebtoken";
import { User } from "../models/user.models.js";
import { ApiError } from "../utils/ApiError.js";

const authMiddleware = async (req, _, next) => {
  try {
    const token = req.cookies?.token || req.header("Authorization")?.replace("Bearer ","");
    if (!token) throw new ApiError(401, "Not authenticated");

    const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET);
    const user = await User.findById(decoded?._id).populate("role");

    if (!user || user.accessToken !== token)
      throw new ApiError(401, "Session expired, please log in again");

    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};

export default authMiddleware;
