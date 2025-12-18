import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";
import { ApiResponse } from "../utils/ApiResponse.js";
import { User } from "../models/user.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import jwt from "jsonwebtoken";
import bcrypt from "bcrypt"


const registerUser = asyncHandler(async (req, res) => {
  const { name, email, password, role } = req.body;

  // Validate required fields
  if ([name, email, password].some((f) => !f?.trim())) {
    throw new ApiError(400, "All fields are required");
  }

  // Validate role - only 'user' or 'admin' allowed
  const validRoles = ['user', 'admin'];
  const userRole = role || 'user'; // default to 'user' if not provided
  
  if (!validRoles.includes(userRole)) {
    throw new ApiError(400, "Role must be either 'user' or 'admin'");
  }

  // Check if user exists
  const existingUser = await User.findOne({ email });
  if (existingUser) {
    throw new ApiError(409, "User already exists with this email");
  }

  const user = await User.create({
    name,
    email,
    password,
    role: userRole,
  });

  const createdUser = await User.findById(user._id)
    .select("-password -accessToken");
    
  if(!createdUser){
    throw new ApiError(500,"Something went wrong while registering user")
  }

  return res
    .status(201)
    .json(new ApiResponse(201, createdUser, "User registered successfully"));
});


const loginUser = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    throw new ApiError(400, "Email and password are required");
  }

  const user = await User.findOne({ email });
  if (!user) throw new ApiError(404, "User not found");

  const isPasswordValid = await user.isPasswordCorrect(password);
  if (!isPasswordValid) throw new ApiError(404, "Invalid credentials");

  // Generate new token and save (invalidate previous)
  const accessToken = user.generateAccessToken();
  user.accessToken = accessToken;
  await user.save();

  const options = {
    httpOnly: true,
    secure: false
  }

  const loggedUser = await User.findById(user._id)
    .select("-password -accessToken");

  // Include token in response for client-side storage
  const userObj = loggedUser.toObject ? loggedUser.toObject() : loggedUser;
  const response = {
    ...userObj,
    token: accessToken,
  };

  return res
    .status(200)
    .cookie("token", accessToken, options)
    .json(new ApiResponse(200, response, "User logged in successfully"));
});


const logoutUser = asyncHandler(async (req, res) => {
  const userId = req.user?._id;

  if (!userId) throw new ApiError(401, "Unauthorized");

  await User.findByIdAndUpdate(userId, { accessToken: null });

  const options = {
    httpOnly: true,
    secure: false
  }

  return res
    .status(200)
    .clearCookie("token", options)
    .json(new ApiResponse(200, {}, "User logged out successfully"));
});

// Get all users
const getAllUsers = async (req, res) => {
  try {
    const users = await User.find({}).select("-password -accessToken").sort({ createdAt: -1 });
    
    res.status(200).json({
      success: true,
      data: users
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Update user
const updateUser = async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    
    // Validate role if provided
    if (role && !['user', 'admin'].includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Role must be either "user" or "admin"'
      });
    }
    
    // Check if user exists
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Check if email is being changed and is unique
    if (email && email !== user.email) {
      const existingUser = await User.findOne({ email });
      if (existingUser) {
        return res.status(409).json({
          success: false,
          message: 'Email already in use'
        });
      }
    }
    
    // Update fields
    if (name) user.name = name;
    if (email) user.email = email;
    if (role) user.role = role;
    if (password) user.password = password; // Will be hashed by pre-save middleware
    
    await user.save();
    
    const updatedUser = await User.findById(user._id).select("-password -accessToken");
    
    res.status(200).json({
      success: true,
      data: updatedUser,
      message: 'User updated successfully'
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// Delete user
const deleteUser = async (req, res) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    // Cascade delete: Remove all project memberships associated with this user
    const deletedMemberships = await ProjectMembership.deleteMany({ user_id: req.params.id });
    console.log(`[User Delete] Removed ${deletedMemberships.deletedCount} membership(s) for user ${req.params.id}`);
    
    res.status(200).json({
      success: true,
      message: 'User deleted successfully',
      deletedMemberships: deletedMemberships.deletedCount
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

export { registerUser, loginUser, logoutUser, getAllUsers, updateUser, deleteUser };


