import ExcelJS from "exceljs";
import mongoose from "mongoose";
import { User } from "../models/user.models.js";
import Project from "../models/project.models.js";
import Stage from "../models/stage.models.js";
import { Role } from "../models/roles.models.js";
import ProjectMembership from "../models/projectMembership.models.js";
import Checkpoint from "../models/checkpoint.models.js";
import { asyncHandler } from "../utils/asyncHandler.js";
import { ApiError } from "../utils/ApiError.js";

/**
 * MASTER EXCEL EXPORT CONTROLLER
 * Generates a comprehensive multi-sheet Excel file for PowerBI analysis
 * Contains all project data, stages, roles, members, checkpoints, and derived defects
 */

// Helper: Safe value extraction (avoid undefined, use null/"")
const safeValue = (val, defaultVal = "") => {
  if (val === null || val === undefined) return defaultVal;
  if (typeof val === "boolean") return val;
  return val;
};

// Helper: Add sheet with headers
const addSheetWithHeaders = (workbook, sheetName, columns) => {
  const sheet = workbook.addWorksheet(sheetName);
  const headerRow = sheet.addRow(columns);

  // Style headers
  headerRow.eachCell((cell) => {
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

  // Auto-fit columns
  sheet.columns.forEach((col) => {
    let maxLength = 15;
    col.eachCell({ includeEmpty: true }, (cell) => {
      if (cell.value) {
        const cellLength = cell.value.toString().length;
        if (cellLength > maxLength) maxLength = cellLength;
      }
    });
    col.width = Math.min(maxLength + 2, 50);
  });

  return sheet;
};

/**
 * GET /admin/export/master-excel
 * Main export endpoint - generates master Excel file with all data
 */
export const exportMasterExcel = asyncHandler(async (req, res) => {
  try {
    console.log("📊 Starting Master Excel export...");

    // Fetch all data in parallel
    const [
      users,
      projects,
      stages,
      roles,
      memberships,
      checklists,
      checkpoints,
      templates,
      checklistAnswers,
    ] = await Promise.all([
      User.find().lean(),
      Project.find().populate("created_by", "name email").lean(),
      Stage.find().lean(),
      Role.find().lean(),
      ProjectMembership.find().populate(["user_id", "role"]).lean(),
      mongoose
        .model("Checklist")
        .find()
        .populate("created_by", "name email")
        .lean(),
      Checkpoint.find().populate("checklistId").lean(),
      mongoose.model("Template").find().lean(),
      mongoose.model("ChecklistAnswer").find().lean(),
    ]);

    console.log(
      `✓ Fetched ${users.length} users, ${projects.length} projects, ${stages.length} stages, ${checklists.length} checklists, ${checkpoints.length} checkpoints, ${checklistAnswers.length} checklist answers`,
    );

    // Debug: Log ALL stages with their counters (not just non-zero)
    console.log(`\n📋 Stage Data (ALL stages with counters):`);
    stages.forEach((stage) => {
      console.log(
        `  Stage: ${stage.stage_name}, Project: ${stage.project_id?.toString().substring(0, 8)}, Loopback: ${stage.loopback_count ?? 0}, Conflict: ${stage.conflict_count ?? 0}`,
      );
    });

    // Debug: Log all reviewer submission summaries
    const reviewerSummaries = checklistAnswers.filter(
      (ans) =>
        ans.role === "reviewer" &&
        ans.sub_question === "_meta_reviewer_summary",
    );
    console.log(
      `📋 Found ${reviewerSummaries.length} reviewer submission summaries`,
    );
    reviewerSummaries.forEach((sum) => {
      console.log(
        `   Project: ${sum.project_id}, Phase: ${sum.phase}, Metadata:`,
        sum.metadata,
        "Remark:",
        sum.remark?.substring(0, 100),
      );
    });

    // Create defect category lookup map (categoryId -> category name)
    // Loop through ALL templates to get all historical categories
    const categoryMap = new Map();
    if (templates && templates.length > 0) {
      console.log(`📂 Found ${templates.length} template(s)`);

      templates.forEach((template, idx) => {
        if (template && template.defectCategories) {
          console.log(
            `\n  Template ${idx + 1}: ${template.defectCategories.length} categories`,
          );
          template.defectCategories.forEach((cat) => {
            if (cat._id && cat.name) {
              const idStr = cat._id.toString();
              categoryMap.set(idStr, cat.name);
              // Also store ObjectId directly
              categoryMap.set(cat._id, cat.name);
              console.log(`     ${idStr} -> ${cat.name}`);
            }
          });
        }
      });

      console.log(
        `\n✓ Loaded ${categoryMap.size / 2} total defect categories from ${templates.length} template(s)`,
      );
    }

    const stageMap = new Map(stages.map((s) => [s._id?.toString(), s]));
    const checklistMap = new Map(checklists.map((c) => [c._id?.toString(), c]));

    // Create role-based user maps for each project
    const projectExecutorMap = new Map(); // project_id -> user_name
    const projectReviewerMap = new Map(); // project_id -> user_name
    const projectTeamLeaderMap = new Map(); // project_id -> user_name

    memberships.forEach((membership) => {
      const projectId = membership.project_id?.toString();
      const userName = membership.user_id?.name || "";
      const roleName = membership.role?.role_name?.toLowerCase() || "";

      if (roleName.includes("executor")) {
        projectExecutorMap.set(projectId, userName);
      } else if (roleName.includes("reviewer")) {
        projectReviewerMap.set(projectId, userName);
      } else if (roleName.includes("teamleader")) {
        projectTeamLeaderMap.set(projectId, userName);
      }
    });

    // Create workbook with SINGLE SHEET ONLY
    const workbook = new ExcelJS.Workbook();

    // Main Sheet: Comprehensive Project Data with Dynamic Phases
    const mainSheet = workbook.addWorksheet("Project Checklist Data");

    // Build dynamic headers based on maximum number of phases
    const maxPhases = Math.max(
      ...projects.map((p) => {
        const projectStages = stages.filter(
          (s) => s.project_id?.toString() === p._id?.toString(),
        );
        return projectStages.length;
      }),
      1,
    );

    const baseHeaders = [
      "Year",
      "Project Number",
      "Project Title",
      "TeamLeader",
      "CreatedDate",
      "Executor",
      "Reviewer",
    ];

    const phaseHeaders = [];
    for (let i = 1; i <= maxPhases; i++) {
      phaseHeaders.push(
        `Phase ${i} - Defect Category`,
        `Phase ${i} - C/NC`,
        `Remark - Phase ${i}`,
        `Phase ${i} - Loopback Count`,
        `Phase ${i} - Conflict Count`,
      );
    }

    const endHeaders = ["Created By", "Project Status"];
    const allHeaders = [...baseHeaders, ...phaseHeaders, ...endHeaders];

    // Add headers with styling
    const headerRow = mainSheet.addRow(allHeaders);
    headerRow.eachCell((cell) => {
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

    // Set column widths - customized per column
    mainSheet.columns.forEach((col, idx) => {
      if (idx === 0) {
        col.width = 12; // Year
      } else if (idx === 1) {
        col.width = 28; // Project Number (~200 pixels)
      } else if (idx === 2) {
        col.width = 70; // Project Title (~500 pixels)
      } else if (idx === 3 || idx === 4) {
        col.width = 18; // TeamLeader, CreatedDate
      } else if (idx === 5 || idx === 6) {
        // Executor and Reviewer - dynamic width based on content
        let maxLength = 15;
        col.eachCell({ includeEmpty: false }, (cell) => {
          if (cell.value) {
            const cellLength = cell.value.toString().length;
            if (cellLength > maxLength) maxLength = cellLength;
          }
        });
        col.width = Math.min(maxLength + 2, 50); // Cap at 50
      } else if (idx >= baseHeaders.length + phaseHeaders.length) {
        col.width = 18; // Created By, Status
      } else {
        // Phase columns - check which type of column it is
        const relativeIdx = (idx - baseHeaders.length) % 5;
        if (relativeIdx === 0) {
          col.width = 55; // Defect Category (~400 pixels)
        } else if (relativeIdx === 1) {
          col.width = 12; // C/NC
        } else if (relativeIdx === 2) {
          col.width = 25; // Remark
        } else if (relativeIdx === 3) {
          col.width = 15; // Loopback Count
        } else {
          col.width = 15; // Conflict Count
        }
      }
    });

    // Process each project and its checklists
    for (const project of projects) {
      const projectId = project._id?.toString();
      const projectStages = stages
        .filter((s) => s.project_id?.toString() === projectId)
        .sort((a, b) => {
          const aNum = parseInt(a.stage_name?.match(/\d+/)?.[0] || "0");
          const bNum = parseInt(b.stage_name?.match(/\d+/)?.[0] || "0");
          return aNum - bNum;
        });

      const projectChecklists = checklists.filter((c) => {
        const stageId = c.stage_id?.toString();
        return projectStages.some((s) => s._id?.toString() === stageId);
      });

      console.log(
        `Project ${project.project_name}: ${projectChecklists.length} checklists, ${projectStages.length} stages`,
      );

      // Get checkpoints for fallback (for existing projects with checkpoint data)
      const projectCheckpoints = checkpoints.filter((cp) => {
        const checklistId =
          cp.checklistId?._id?.toString() || cp.checklistId?.toString();
        return projectChecklists.some((c) => c._id?.toString() === checklistId);
      });

      // If no checklists, add one row for the project with all phase data from reviewer summaries
      if (projectChecklists.length === 0) {
        const rowData = [
          safeValue(new Date(project.createdAt).getFullYear()),
          safeValue(project.project_no || ""),
          safeValue(project.project_name),
          safeValue(projectSDHMap.get(projectId)),
          safeValue(
            project.createdAt
              ? new Date(project.createdAt).toISOString().split("T")[0]
              : "",
          ),
          safeValue(projectExecutorMap.get(projectId)),
          safeValue(projectReviewerMap.get(projectId)),
        ];

        // Add phase data from reviewer summaries
        for (let i = 1; i <= maxPhases; i++) {
          // Look for reviewer summary for this phase
          const reviewerSummary = checklistAnswers.find(
            (ans) =>
              ans.project_id?.toString() === projectId &&
              ans.phase === i &&
              ans.role === "reviewer" &&
              ans.sub_question === "_meta_reviewer_summary",
          );

          // Get stage data for this phase using stage_key (e.g., "stage1", "stage2")
          const phaseStage = projectStages.find((s) => {
            // Match by stage_key (e.g., "stage1" for phase 1)
            if (s.stage_key === `stage${i}`) {
              return true;
            }
            // Fallback: try to extract number from stage_name
            const phaseMatch = s.stage_name?.match(/\d+/);
            const phaseNumber = phaseMatch ? parseInt(phaseMatch[0]) : 0;
            return phaseNumber === i;
          });

          console.log(`  Phase ${i}: Looking for stage with stage_key="stage${i}", projectStages count: ${projectStages.length}`);
          if (phaseStage) {
            console.log(`    Found stage: ${phaseStage.stage_name} (${phaseStage.stage_key}), loopback_count: ${phaseStage.loopback_count}, conflict_count: ${phaseStage.conflict_count}`);
          } else {
            console.log(`    Stage not found for phase ${i}`);
            if (projectStages.length > 0) {
              console.log(`    Available stages:`, projectStages.map(s => ({ name: s.stage_name, key: s.stage_key, loopback: s.loopback_count, conflict: s.conflict_count })));
            }
          }

          // Only show counts if reviewer has submitted data for this phase
          let loopbackCount = "";
          let conflictCount = "";

          if (reviewerSummary) {
            if (phaseStage) {
              loopbackCount = phaseStage.loopback_count ?? 0;
              conflictCount = phaseStage.conflict_count ?? 0;
              console.log(
                `  Phase ${i}: Reviewer summary exists, setting counters - Loopback: ${loopbackCount}, Conflict: ${conflictCount}`,
              );
            } else {
              console.log(`  Phase ${i}: Reviewer summary exists but stage not found, using 0s`);
              loopbackCount = 0;
              conflictCount = 0;
            }
          }

          if (reviewerSummary) {
            let summaryData = reviewerSummary.metadata?._summaryData;

            // If _summaryData not in metadata, try parsing remark
            if (!summaryData && reviewerSummary.remark) {
              try {
                summaryData = JSON.parse(reviewerSummary.remark);
              } catch (e) {
                // Ignore parse errors
              }
            }

            if (summaryData) {
              const categoryId = summaryData.category || "";
              const categoryName = summaryData.categoryName || ""; // Get the stored name
              const cOrNC = summaryData.severity || "";
              const remark = summaryData.remark || "";

              // Use the stored category name if available, otherwise try lookup
              let defectCategory = categoryName;
              if (!defectCategory && categoryId) {
                defectCategory = categoryMap.get(categoryId.toString());
                if (!defectCategory) {
                  // Category not found - it's from an old/deleted template
                  defectCategory = `[Deleted Category: ${categoryId}]`;
                  console.log(
                    `  ⚠️ Phase ${i}: Category ID "${categoryId}" not found in current templates (from deleted/old template)`,
                  );
                }
              }

              console.log(
                `  Phase ${i}: CategoryId="${categoryId}", CategoryName="${categoryName}", Category="${defectCategory}", Severity="${cOrNC}", Remark="${remark?.substring(0, 20)}", Loopback=${loopbackCount}, Conflict=${conflictCount}`,
              );

              rowData.push(
                safeValue(defectCategory),
                safeValue(cOrNC),
                safeValue(remark),
                safeValue(loopbackCount),
                safeValue(conflictCount),
              );
            } else {
              rowData.push("", "", "", safeValue(loopbackCount), safeValue(conflictCount));
            }
          } else {
            // No reviewer summary - leave all empty
            rowData.push("", "", "", "", "");
          }
        }

        rowData.push(
          safeValue(project.created_by?.name || project.created_by?.email),
          safeValue(project.status),
        );

        mainSheet.addRow(rowData);
      } else {
        // Add a row for each checklist
        for (const checklist of projectChecklists) {
          const stageId = checklist.stage_id?.toString();
          const stage = stages.find((s) => s._id?.toString() === stageId);

          // Determine phase number from stage
          const phaseMatch = stage?.stage_name?.match(/\d+/);
          const phaseNumber = phaseMatch ? parseInt(phaseMatch[0]) : 0;

          // Get checkpoints for this checklist (for fallback data)
          const checklistCheckpoints = projectCheckpoints.filter((cp) => {
            const cpChecklistId =
              cp.checklistId?._id?.toString() || cp.checklistId?.toString();
            return cpChecklistId === checklist._id?.toString();
          });

          // DEBUG: Log checklist data structure
          console.log(
            `  Checklist: ${checklist.checklist_name?.substring(0, 30)}... Phase: ${phaseNumber}, Stage: ${stage?.stage_name}`,
          );
          console.log(`    defectCategory: ${checklist.defectCategory}`);
          console.log(`    defectSeverity: ${checklist.defectSeverity}`);
          console.log(`    remark: ${checklist.remark}`);
          console.log(
            `    Checkpoints: ${checklistCheckpoints.length} checkpoints`,
          );

          const rowData = [
            safeValue(new Date(project.createdAt).getFullYear()),
            safeValue(project.project_no || ""),
            safeValue(project.project_name),
            safeValue(projectSDHMap.get(projectId)),
            safeValue(
              checklist.createdAt
                ? new Date(checklist.createdAt).toISOString().split("T")[0]
                : "",
            ),
            safeValue(projectExecutorMap.get(projectId)),
            safeValue(projectReviewerMap.get(projectId)),
          ];

          // Add phase data - fill all phases
          for (let i = 1; i <= maxPhases; i++) {
            // Get stage data for this phase using stage_key (e.g., "stage1", "stage2")
            const phaseStage = projectStages.find((s) => {
              // Match by stage_key (e.g., "stage1" for phase 1)
              if (s.stage_key === `stage${i}`) {
                return true;
              }
              // Fallback: try to extract number from stage_name
              const phaseMatch = s.stage_name?.match(/\d+/);
              const phaseNum = phaseMatch ? parseInt(phaseMatch[0]) : 0;
              return phaseNum === i;
            });

            console.log(`    Phase ${i}: Looking for stage with stage_key="stage${i}" in ${projectStages.length} stages`);
            if (phaseStage) {
              console.log(`      Found stage: ${phaseStage.stage_name} (${phaseStage.stage_key}), loopback: ${phaseStage.loopback_count}, conflict: ${phaseStage.conflict_count}`);
            } else {
              console.log(`      Stage not found for phase ${i}`);
              if (projectStages.length > 0) {
                console.log(`      Available stages:`, projectStages.map(s => ({ name: s.stage_name, key: s.stage_key, loopback: s.loopback_count, conflict: s.conflict_count })));
              }
            }

            // Check if reviewer has submitted data for this phase
            const hasReviewerData = checklistAnswers.some(
              (ans) =>
                ans.project_id?.toString() === projectId &&
                ans.phase === i &&
                ans.role === "reviewer" &&
                ans.sub_question === "_meta_reviewer_summary",
            );

            console.log(`      Has reviewer data: ${hasReviewerData}`);

            // Only show counts if reviewer has submitted data
            let loopbackCount = "";
            let conflictCount = "";

            if (hasReviewerData) {
              if (phaseStage) {
                loopbackCount = phaseStage.loopback_count ?? 0;
                conflictCount = phaseStage.conflict_count ?? 0;
                console.log(`      Setting counters: Loopback=${loopbackCount}, Conflict=${conflictCount}`);
              } else {
                console.log(`      Reviewer data exists but no stage found, using 0s`);
                loopbackCount = 0;
                conflictCount = 0;
              }
            }

            if (i === phaseNumber && phaseNumber > 0) {
              // This is the current phase for this checklist

              let categoryId = "";
              let cOrNC = "";
              let remark = "";
              let reviewerCategoryName = ""; // Store the category name from reviewer summary

              // FIRST: Try to get data from reviewer submission summary (HIGHEST PRIORITY)
              const reviewerSummary = checklistAnswers.find(
                (ans) =>
                  ans.project_id?.toString() === projectId &&
                  ans.phase === phaseNumber &&
                  ans.role === "reviewer" &&
                  ans.sub_question === "_meta_reviewer_summary",
              );

              if (reviewerSummary) {
                console.log(
                  `    Found reviewer summary for phase ${phaseNumber}:`,
                  reviewerSummary.metadata || reviewerSummary.remark,
                );

                // Parse metadata or remark
                let summaryData = reviewerSummary.metadata;

                // If metadata not available, try parsing remark as JSON
                if (!summaryData && reviewerSummary.remark) {
                  try {
                    summaryData = JSON.parse(reviewerSummary.remark);
                  } catch (e) {
                    console.log(
                      `    Could not parse remark as JSON: ${reviewerSummary.remark}`,
                    );
                  }
                }

                if (summaryData) {
                  categoryId = summaryData.category || "";
                  const categoryName = summaryData.categoryName || ""; // Get the stored name
                  cOrNC = summaryData.severity || "";
                  remark = summaryData.remark || "";

                  console.log(
                    `    Using reviewer summary: CategoryId="${categoryId}", CategoryName="${categoryName}", Severity="${cOrNC}", Remark="${remark?.substring(0, 20)}"`,
                  );

                  // Store the category name for later use
                  if (categoryName) {
                    reviewerCategoryName = categoryName;
                  }
                }
              }

              // SECOND: If no reviewer summary, try checklist fields
              if (!categoryId && !cOrNC && !remark) {
                categoryId = checklist.defectCategory || "";
                cOrNC = checklist.defectSeverity || "";
                remark = checklist.remark || "";

                if (categoryId || cOrNC || remark) {
                  console.log(
                    `    Using checklist data: Category="${categoryId}", Severity="${cOrNC}", Remark="${remark?.substring(0, 20)}"`,
                  );
                }
              }

              // Fallback: If checklist doesn't have data, aggregate from checkpoints
              if (
                !categoryId &&
                !cOrNC &&
                !remark &&
                checklistCheckpoints.length > 0
              ) {
                console.log(
                  `    No data in checklist or reviewer summary, falling back to ${checklistCheckpoints.length} checkpoints`,
                );

                // Aggregate checkpoint data
                const checkpointData = checklistCheckpoints.map((cp) => ({
                  categoryId: cp.defect?.categoryId || cp.categoryId || "",
                  severity: cp.defect?.severity || "",
                  isDetected: cp.defect?.isDetected || false,
                  executorAnswer: cp.executorResponse?.answer,
                  reviewerAnswer: cp.reviewerResponse?.answer,
                  executorRemark: cp.executorResponse?.remark || "",
                  reviewerRemark: cp.reviewerResponse?.remark || "",
                }));

                // Get first non-empty category
                categoryId =
                  checkpointData.find((cp) => cp.categoryId)?.categoryId || "";

                // Get first non-empty severity or determine from answers
                const firstCheckpoint = checkpointData[0];
                if (firstCheckpoint) {
                  if (firstCheckpoint.isDetected) {
                    cOrNC = firstCheckpoint.severity || "Non-Critical";
                  } else if (firstCheckpoint.executorAnswer === true) {
                    cOrNC = "C";
                  } else if (firstCheckpoint.executorAnswer === false) {
                    cOrNC = "NC";
                  } else if (firstCheckpoint.reviewerAnswer === true) {
                    cOrNC = "C";
                  } else if (firstCheckpoint.reviewerAnswer === false) {
                    cOrNC = "NC";
                  }

                  // Get first non-empty remark
                  remark =
                    firstCheckpoint.executorRemark ||
                    firstCheckpoint.reviewerRemark ||
                    "";
                }

                console.log(
                  `    Fallback data: Category="${categoryId}", Severity="${cOrNC}", Remark="${remark?.substring(0, 20)}"`,
                );
              }

              // Convert categoryId to category name
              // Use the stored category name from reviewer summary if available
              let defectCategory = reviewerCategoryName || "";
              if (!defectCategory && categoryId) {
                defectCategory = categoryMap.get(categoryId.toString());
                if (!defectCategory) {
                  // Category not found - it's from an old/deleted template
                  defectCategory = `[Deleted Category: ${categoryId}]`;
                  console.log(
                    `    ⚠️ Phase ${i}: Category ID "${categoryId}" not found in current templates (from deleted/old template)`,
                  );
                }
              }

              console.log(
                `    Phase ${i} data: CategoryId="${categoryId}", CategoryName="${reviewerCategoryName}", Category="${defectCategory}", C/NC="${cOrNC}", Remark="${remark?.substring(0, 20)}", Loopback=${loopbackCount}, Conflict=${conflictCount}`,
              );

              rowData.push(
                safeValue(defectCategory),
                safeValue(cOrNC),
                safeValue(remark),
                safeValue(loopbackCount),
                safeValue(conflictCount),
              );
            } else {
              // Not the current phase or no data - leave empty if no reviewer data
              rowData.push("", "", "", safeValue(loopbackCount), safeValue(conflictCount));
            }
          }

          rowData.push(
            safeValue(
              checklist?.created_by?.name ||
                checklist?.created_by?.email ||
                project.created_by?.name,
            ),
            safeValue(project.status),
          );

          mainSheet.addRow(rowData);
        }
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

    console.log(
      `✓ Master Excel export completed. File size: ${buffer.length} bytes`,
    );
    res.send(buffer);
  } catch (error) {
    console.error("❌ Export error:", error);
    throw error;
  }
});
