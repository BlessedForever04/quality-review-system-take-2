import express from "express";
import cookieParser from "cookie-parser";
import cors from "cors";
const app = express();

app.use(
  cors({
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json({ limit: "16kb" }));
app.use(express.urlencoded({ extended: true, limit: "16kb" }));

app.use(cookieParser());

//routes
import userRouter from "./routes/user.routes.js";
import roleRoutes from "./routes/role.routes.js";
import projectMembershipRoutes from "./routes/projectMembership.routes.js";
import projectRoutes from "./routes/project.routes.js";
import checklistRoutes from "./routes/checklistRoutes.js";
import checklistAnswerRoutes from "./routes/checklistAnswerRoutes.js";
import stageRouter from "./routes/stage.routes.js";
import approvalRoutes from "./routes/approval.routes.js";
import projectChecklistRoutes from "./routes/projectChecklist.routes.js";
// New routes for template and checkpoint features (integrated from V3)
import templateRoutes from "./routes/template.routes.js";
import checkpointRoutes from "./routes/checkpoint.routes.js";
import analyticsRoutes from "./routes/analytics.routes.js";
import exportRoutes from "./routes/export.routes.js";
import imagesRouter from "./routes/images.js";

//routes declaration
app.use("/api/v1/users", userRouter);
app.use("/api/v1/roles", roleRoutes);
// Mount membership routes BEFORE project routes to avoid ":id" catching "members"
app.use("/api/v1/projects", projectMembershipRoutes);
app.use("/api/v1/projects", projectRoutes);
// Mount checklist routes at the API root so routes like
// GET /api/v1/stages/:stageId/checklists work as defined in checklistRoutes
app.use("/api/v1", checklistRoutes);
app.use("/api/v1", checklistAnswerRoutes);
app.use("/api/v1", stageRouter);
app.use("/api/v1", approvalRoutes);
app.use("/api/v1", projectChecklistRoutes);
// Template and checkpoint routes (integrated from V3)
app.use("/api/v1/templates", templateRoutes);
app.use("/api/v1", checkpointRoutes);
// Analytics routes for defect analysis
app.use("/api/v1", analyticsRoutes);
// Export routes for master Excel export
app.use("/api/v1", exportRoutes);
// GridFS image upload/list/download routes
app.use("/api/v1", imagesRouter);

// Global error handler - must be last
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal Server Error";

  res.status(statusCode).json({
    statusCode: statusCode,
    message: message,
    success: false,
    data: null,
  });
});

// 404 handler - must be after all routes
app.use((req, res) => {
  res.status(404).json({
    statusCode: 404,
    message: "Route not found",
    success: false,
    data: null,
  });
});

export { app };
