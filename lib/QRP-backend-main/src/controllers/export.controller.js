import ExcelJS from "exceljs";
import mongoose from "mongoose";
import { User } from "../models/user.models.js";
import Project from "../models/project.models.js";
import Stage from "../models/stage.models.js";
import { Role } from "../models/roles.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";

/**
 * MASTER EXCEL EXPORT CONTROLLER
 * Generates a comprehensive Excel file with question-level checklist data (Latest Iteration Only)
 * Contains all questions, responses, remarks, and defect information per question
 */

// Helper: Safe value extraction (avoid undefined, use null/"")
const safeValue = (val, defaultVal = "") => {
  if (val === null || val === undefined) return defaultVal;
  if (typeof val === "boolean") return val;
  return val;
};

/**
 * GET /admin/export/master-excel
 * Main export endpoint - generates master Excel file with comprehensive question-level data
 * Shows only the latest/final iteration data for each project
 */
export const exportMasterExcel = asyncHandler(async (req, res) => {
  try {
    // Fetch all data in parallel
    const [
      users,
      projects,
      stages,
      roles,
      memberships,
      templates,
      projectChecklists,
    ] = await Promise.all([
      User.find().lean(),
      Project.find().populate("created_by", "name email").lean(),
      Stage.find().lean(),
      Role.find().lean(),
      ProjectMembership.find().populate(["user_id", "role"]).lean(),
      mongoose.model("Template").find().lean(),
      mongoose.model("ProjectChecklist").find().lean(),
    ]);

    // Create defect category lookup map
    const categoryMap = new Map();
    if (templates && templates.length > 0) {
      templates.forEach((template) => {
        if (template && template.defectCategories) {
          template.defectCategories.forEach((cat) => {
            if (cat._id && cat.name) {
              categoryMap.set(cat._id.toString(), cat.name);
            }
          });
        }
      });
    }

    // Create role-based user maps for each project (support multiple users per role)
    const projectExecutorsMap = new Map(); // project_id -> array of executor names
    const projectReviewersMap = new Map(); // project_id -> array of reviewer names
    const projectTeamLeadersMap = new Map(); // project_id -> array of team leader names

    memberships.forEach((membership) => {
      const projectId = membership.project_id?.toString();
      const userName = membership.user_id?.name || "";
      const roleName = membership.role?.role_name?.toLowerCase() || "";

      if (!userName) return;

      if (roleName.includes("executor")) {
        if (!projectExecutorsMap.has(projectId)) {
          projectExecutorsMap.set(projectId, []);
        }
        projectExecutorsMap.get(projectId).push(userName);
      } else if (roleName.includes("reviewer")) {
        if (!projectReviewersMap.has(projectId)) {
          projectReviewersMap.set(projectId, []);
        }
        projectReviewersMap.get(projectId).push(userName);
      } else if (roleName.includes("teamleader")) {
        if (!projectTeamLeadersMap.has(projectId)) {
          projectTeamLeadersMap.set(projectId, []);
        }
        projectTeamLeadersMap.get(projectId).push(userName);
      }
    });

    // Create workbook with multiple sheets
    const workbook = new ExcelJS.Workbook();

    // ===== Sheet 1: Project Summary =====
    const summarySheet = workbook.addWorksheet("Project Summary");
    const summaryHeaders = [
      "Year",
      "Project Number",
      "Project Name",
      "Created Date",
      "Team Leaders",
      "Executors",
      "Reviewers",
      "Is Review Applicable",
      "Overall Defect Rate (%)",
      "Project Status",
      "Total Phases",
      "Created By",
    ];

    const summaryHeaderRow = summarySheet.addRow(summaryHeaders);
    summaryHeaderRow.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FF366092" },
      };
      cell.alignment = {
        horizontal: "center",
        vertical: "center",
        wrapText: true,
      };
    });

    summarySheet.columns = [
      { width: 10 }, // Year
      { width: 25 }, // Project Number
      { width: 50 }, // Project Name
      { width: 18 }, // Created Date
      { width: 30 }, // Team Leaders
      { width: 30 }, // Executors
      { width: 30 }, // Reviewers
      { width: 20 }, // Is Review Applicable
      { width: 22 }, // Overall Defect Rate (%)
      { width: 15 }, // Project Status
      { width: 15 }, // Total Phases
      { width: 20 }, // Created By
    ];

    // ===== Sheet 2: Detailed Questions and Answers =====
    const detailSheet = workbook.addWorksheet("Questions & Answers");
    const detailHeaders = [
      "Year",
      "Project Number",
      "Project Name",
      "Created Date",
      "Project Status",
      "Phase",
      "Checklist Group",
      "Section",
      "Question",
      "Executor Remark",
      "Reviewer Remark",
      "Defect Category",
      "Defect Severity",
      "Phase Conflict Count",
    ];

    const detailHeaderRow = detailSheet.addRow(detailHeaders);
    detailHeaderRow.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FF366092" },
      };
      cell.alignment = {
        horizontal: "center",
        vertical: "center",
        wrapText: true,
      };
    });

    detailSheet.columns = [
      { width: 10 }, // Year
      { width: 25 }, // Project Number
      { width: 50 }, // Project Name
      { width: 18 }, // Created Date
      { width: 15 }, // Project Status
      { width: 10 }, // Phase
      { width: 30 }, // Checklist Group
      { width: 30 }, // Section
      { width: 60 }, // Question
      { width: 40 }, // Executor Remark
      { width: 40 }, // Reviewer Remark
      { width: 40 }, // Defect Category
      { width: 18 }, // Defect Severity
      { width: 18 }, // Conflict Count
    ];

    // ===== Sheet 3: Employee Performance =====
    const employeeSheet = workbook.addWorksheet("Employee Performance");
    const employeeHeaders = [
      "Employee Name",
      "Email",
      "Completed Projects",
      "Ongoing Projects",
      "Total Assigned Projects",
      "Average Defect Rate (%)",
    ];

    const employeeHeaderRow = employeeSheet.addRow(employeeHeaders);
    employeeHeaderRow.eachCell((cell) => {
      cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
      cell.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: { argb: "FF366092" },
      };
      cell.alignment = {
        horizontal: "center",
        vertical: "center",
        wrapText: true,
      };
    });

    employeeSheet.columns = [
      { width: 30 }, // Employee Name
      { width: 35 }, // Email
      { width: 20 }, // Completed Projects
      { width: 20 }, // Ongoing Projects
      { width: 25 }, // Total Assigned Projects
      { width: 22 }, // Average Defect Rate (%)
    ];

    // Create employee performance map
    const employeePerformanceMap = new Map();

    // Loop through all memberships to aggregate employee data
    memberships.forEach((membership) => {
      const userId = membership.user_id?._id?.toString();
      const userName = membership.user_id?.name || "";
      const userEmail = membership.user_id?.email || "";
      const projectId = membership.project_id?.toString();

      if (!userId || !userName || !projectId) return;

      // Find the project
      const project = projects.find((p) => p._id?.toString() === projectId);
      if (!project) return;

      // Initialize employee data if not exists
      if (!employeePerformanceMap.has(userId)) {
        employeePerformanceMap.set(userId, {
          name: userName,
          email: userEmail,
          completedProjects: new Set(),
          ongoingProjects: new Set(),
          totalProjects: new Set(),
          defectRates: [],
        });
      }

      const empData = employeePerformanceMap.get(userId);
      empData.totalProjects.add(projectId);

      // Check project status - count all non-completed projects as ongoing
      const status = project.status?.toLowerCase() || "";
      if (status === "completed") {
        empData.completedProjects.add(projectId);
      } else {
        // Any status other than completed is considered ongoing
        empData.ongoingProjects.add(projectId);
      }

      // Add defect rate if available (only count each project once per employee)
      if (
        project.overallDefectRate !== null &&
        project.overallDefectRate !== undefined &&
        !empData.defectRates.find((dr) => dr.projectId === projectId)
      ) {
        empData.defectRates.push({
          projectId: projectId,
          rate: project.overallDefectRate,
        });
      }
    });

    // Add employee data to sheet
    employeePerformanceMap.forEach((empData) => {
      const avgDefectRate =
        empData.defectRates.length > 0
          ? (
              empData.defectRates.reduce((sum, dr) => sum + dr.rate, 0) /
              empData.defectRates.length
            ).toFixed(2)
          : "";

      employeeSheet.addRow([
        safeValue(empData.name),
        safeValue(empData.email),
        empData.completedProjects.size,
        empData.ongoingProjects.size,
        empData.totalProjects.size,
        safeValue(avgDefectRate),
      ]);
    });

    // ===== Process each project =====
    for (const project of projects) {
      const projectId = project._id?.toString();

      // Extract year from first 4 characters of project number
      const year = project.project_no ? project.project_no.substring(0, 4) : "";

      // Get stages for this project
      const projectStages = stages
        .filter((s) => s.project_id?.toString() === projectId)
        .sort((a, b) => {
          const aNum = parseInt(a.stage_name?.match(/\d+/)?.[0] || "0");
          const bNum = parseInt(b.stage_name?.match(/\d+/)?.[0] || "0");
          return aNum - bNum;
        });

      // Get team members
      const executors = projectExecutorsMap.get(projectId) || [];
      const reviewers = projectReviewersMap.get(projectId) || [];
      const teamLeaders = projectTeamLeadersMap.get(projectId) || [];

      const executorsStr = executors.join(", ");
      const reviewersStr = reviewers.join(", ");
      const teamLeadersStr = teamLeaders.join(", ");

      // Add to summary sheet
      const isReviewApplicable =
        project.isReviewApplicable === null ||
        project.isReviewApplicable === undefined
          ? ""
          : project.isReviewApplicable === "yes"
            ? "Yes"
            : "No";

      const overallDefectRate =
        project.overallDefectRate !== null &&
        project.overallDefectRate !== undefined
          ? project.overallDefectRate.toFixed(2)
          : "";

      summarySheet.addRow([
        safeValue(year),
        safeValue(project.project_no || ""),
        safeValue(project.project_name),
        safeValue(
          project.createdAt
            ? new Date(project.createdAt).toISOString().split("T")[0]
            : "",
        ),
        safeValue(teamLeadersStr),
        safeValue(executorsStr),
        safeValue(reviewersStr),
        safeValue(isReviewApplicable),
        safeValue(overallDefectRate),
        safeValue(project.status),
        safeValue(projectStages.length),
        safeValue(project.created_by?.name || project.created_by?.email || ""),
      ]);

      // Get all project checklists for this project
      const projectChecklistDocs = projectChecklists.filter(
        (pc) => pc.projectId?.toString() === projectId,
      );

      if (projectChecklistDocs.length === 0) {
        // Add a row indicating no data
        detailSheet.addRow([
          safeValue(year),
          safeValue(project.project_no || ""),
          safeValue(project.project_name),
          safeValue(
            project.createdAt
              ? new Date(project.createdAt).toISOString().split("T")[0]
              : "",
          ),
          safeValue(project.status),
          "",
          "",
          "",
          "No checklist data available",
          "",
          "",
          "",
          "",
          "",
        ]);
        continue;
      }

      // Process each phase
      for (const stage of projectStages) {
        const stageId = stage._id?.toString();
        const phaseMatch = stage.stage_name?.match(/\d+/);
        const phaseNumber = phaseMatch ? parseInt(phaseMatch[0]) : 0;

        // Find the project checklist for this stage
        const projectChecklistDoc = projectChecklistDocs.find(
          (pc) => pc.stageId?.toString() === stageId,
        );

        if (!projectChecklistDoc) {
          continue;
        }

        const currentIteration = projectChecklistDoc.currentIteration || 1;

        // Use the current/latest data from groups (not historical iterations)
        const groups = projectChecklistDoc.groups || [];

        if (groups.length === 0) {
          detailSheet.addRow([
            safeValue(year),
            safeValue(project.project_no || ""),
            safeValue(project.project_name),
            safeValue(
              project.createdAt
                ? new Date(project.createdAt).toISOString().split("T")[0]
                : "",
            ),
            safeValue(project.status),
            safeValue(phaseNumber),
            "",
            "",
            "No questions in this phase",
            "",
            "",
            "",
            "",
            safeValue(stage.conflict_count ?? 0),
          ]);
          continue;
        }

        // Process each group
        groups.forEach((group) => {
          const groupName = group.groupName || "";

          // Process direct questions on the group
          if (group.questions && Array.isArray(group.questions)) {
            group.questions.forEach((question) => {
              const categoryName = question.categoryId
                ? categoryMap.get(question.categoryId.toString()) ||
                  `[Unknown: ${question.categoryId}]`
                : "";

              detailSheet.addRow([
                safeValue(year),
                safeValue(project.project_no || ""),
                safeValue(project.project_name),
                safeValue(
                  project.createdAt
                    ? new Date(project.createdAt).toISOString().split("T")[0]
                    : "",
                ),
                safeValue(project.status),
                safeValue(phaseNumber),
                safeValue(groupName),
                "", // No section
                safeValue(question.text || ""),
                safeValue(question.executorRemark || ""),
                safeValue(question.reviewerRemark || ""),
                safeValue(categoryName),
                safeValue(question.severity || ""),
                safeValue(stage.conflict_count ?? 0),
              ]);
            });
          }

          // Process sections within the group
          if (group.sections && Array.isArray(group.sections)) {
            group.sections.forEach((section) => {
              const sectionName = section.sectionName || "";

              if (section.questions && Array.isArray(section.questions)) {
                section.questions.forEach((question) => {
                  const categoryName = question.categoryId
                    ? categoryMap.get(question.categoryId.toString()) ||
                      `[Unknown: ${question.categoryId}]`
                    : "";

                  detailSheet.addRow([
                    safeValue(year),
                    safeValue(project.project_no || ""),
                    safeValue(project.project_name),
                    safeValue(
                      project.createdAt
                        ? new Date(project.createdAt)
                            .toISOString()
                            .split("T")[0]
                        : "",
                    ),
                    safeValue(project.status),
                    safeValue(phaseNumber),
                    safeValue(groupName),
                    safeValue(sectionName),
                    safeValue(question.text || ""),
                    safeValue(question.executorRemark || ""),
                    safeValue(question.reviewerRemark || ""),
                    safeValue(categoryName),
                    safeValue(question.severity || ""),
                    safeValue(stage.conflict_count ?? 0),
                  ]);
                });
              }
            });
          }
        });
      }
    }

    // Write to buffer
    const buffer = await workbook.xlsx.writeBuffer();

    // Set response headers for download
    res.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="master_export_${new Date().toISOString().split("T")[0]}_${Date.now()}.xlsx"`,
    );
    res.setHeader("Content-Length", buffer.length);

    res.send(buffer);
  } catch (error) {
    throw error;
  }
});
