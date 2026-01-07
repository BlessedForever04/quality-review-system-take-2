/**
 * Script to load 41 default defect categories into the template
 * Run: node load_default_categories.js
 */

import mongoose from "mongoose";
import dotenv from "dotenv";
import Template from "./src/models/template.models.js";

dotenv.config();

const defaultCategories = [
  // Geometry/Modeling Issues (6)
  {
    name: "Incorrect Modelling Strategy - Geometry",
    keywords: [
      "geometry",
      "modeling strategy",
      "model approach",
      "incorrect strategy",
      "geometric error",
    ],
    color: "#FF5722",
  },
  {
    name: "Incorrect Modelling Strategy - Material",
    keywords: [
      "material",
      "material property",
      "material assignment",
      "incorrect",
      "wrong material",
    ],
    color: "#FF6F00",
  },
  {
    name: "Incorrect Modelling Strategy - Loads",
    keywords: ["loads", "loading", "force", "pressure", "applied loads"],
    color: "#F57C00",
  },
  {
    name: "Incorrect Modelling Strategy - BC",
    keywords: ["boundary condition", "BC", "constraints", "support", "fixity"],
    color: "#EF6C00",
  },
  {
    name: "Incorrect Modelling Strategy - Assumptions",
    keywords: [
      "assumption",
      "assumptions",
      "simplified",
      "approximation",
      "idealization",
    ],
    color: "#E65100",
  },
  {
    name: "Incorrect Modelling Strategy - Acceptance Criteria",
    keywords: [
      "acceptance criteria",
      "criteria",
      "limits",
      "threshold",
      "allowable",
      "specification",
    ],
    color: "#D84315",
  },

  // Mesh Issues (6)
  {
    name: "Incorrect geometry units",
    keywords: ["units", "geometry units", "mm", "cm", "meter", "measurement"],
    color: "#9C27B0",
  },
  {
    name: "Incorrect meshing",
    keywords: ["mesh", "meshing", "element size", "mesh quality", "refinement"],
    color: "#7B1FA2",
  },
  {
    name: "Missing geometry",
    keywords: ["missing", "geometry", "incomplete", "absent", "not modeled"],
    color: "#6A1B9A",
  },
  {
    name: "Uncaptured geometry",
    keywords: ["uncaptured", "ignored", "omitted", "not included"],
    color: "#4A148C",
  },
  {
    name: "Incorrect contact definition",
    keywords: [
      "contact",
      "contact definition",
      "bonded",
      "friction",
      "interface",
      "connection",
    ],
    color: "#8E24AA",
  },
  {
    name: "Incorrect beam/bolt modeling",
    keywords: ["beam", "bolt", "beam element", "bolt connection", "fastener"],
    color: "#AB47BC",
  },

  // Element Issues (7)
  {
    name: "Incorrect loads and Boundary Condition",
    keywords: [
      "loads",
      "boundary condition",
      "BC",
      "force",
      "constraint",
      "support",
    ],
    color: "#3F51B5",
  },
  {
    name: "Incorrect connectivity",
    keywords: [
      "connectivity",
      "connection",
      "linked",
      "joined",
      "incorrect",
      "disconnected",
    ],
    color: "#3949AB",
  },
  {
    name: "Incorrect degree of element order",
    keywords: [
      "element order",
      "linear",
      "quadratic",
      "degree",
      "shape function",
    ],
    color: "#303F9F",
  },
  {
    name: "Incorrect element formulation",
    keywords: [
      "element formulation",
      "formulation",
      "element type",
      "shell",
      "solid",
      "beam",
    ],
    color: "#283593",
  },
  {
    name: "Missing element",
    keywords: ["missing element", "element missing", "absent", "not meshed"],
    color: "#1A237E",
  },
  {
    name: "Incorrect element midside node",
    keywords: ["midside node", "mid-node", "element node", "node position"],
    color: "#5C6BC0",
  },
  {
    name: "Sizing issue",
    keywords: ["sizing", "size", "element size", "mesh size", "dimensions"],
    color: "#7986CB",
  },

  // Material & Property Issues (5)
  {
    name: "Missing material",
    keywords: ["missing material", "no material", "material not assigned"],
    color: "#00BCD4",
  },
  {
    name: "Incorrect material parameters",
    keywords: [
      "material parameters",
      "material properties",
      "modulus",
      "poisson",
      "density",
      "incorrect",
    ],
    color: "#0097A7",
  },
  {
    name: "Missing property",
    keywords: ["missing property", "property", "thickness", "section"],
    color: "#00838F",
  },
  {
    name: "Incorrect properties",
    keywords: [
      "incorrect properties",
      "wrong property",
      "thickness error",
      "section error",
    ],
    color: "#006064",
  },
  {
    name: "Incorrect units",
    keywords: [
      "units",
      "unit system",
      "mm",
      "meter",
      "kg",
      "ton",
      "conversion",
    ],
    color: "#00ACC1",
  },

  // Analysis & Solution Issues (8)
  {
    name: "Result file empty",
    keywords: ["result file", "empty", "no results", "output missing"],
    color: "#009688",
  },
  {
    name: "Time requirement",
    keywords: ["time", "duration", "analysis time", "solving time", "runtime"],
    color: "#00897B",
  },
  {
    name: "Analysis not run",
    keywords: ["analysis not run", "not executed", "job not submitted"],
    color: "#00796B",
  },
  {
    name: "Analysis terminated or failed",
    keywords: [
      "terminated",
      "failed",
      "error",
      "analysis error",
      "job failed",
      "crashed",
    ],
    color: "#00695C",
  },
  {
    name: "Solver/Solution setup issue",
    keywords: ["solver", "solution setup", "solver settings", "convergence"],
    color: "#004D40",
  },
  {
    name: "Incorrect physics",
    keywords: [
      "physics",
      "analysis type",
      "linear",
      "nonlinear",
      "static",
      "dynamic",
      "incorrect",
    ],
    color: "#26A69A",
  },
  {
    name: "Incorrect analysis type",
    keywords: [
      "analysis type",
      "structural",
      "thermal",
      "modal",
      "frequency",
      "incorrect",
    ],
    color: "#4DB6AC",
  },
  {
    name: "Insufficient resource",
    keywords: [
      "resource",
      "memory",
      "disk space",
      "CPU",
      "insufficient",
      "out of memory",
    ],
    color: "#80CBC4",
  },

  // Quality & Reporting Issues (9)
  {
    name: "Mesh quality bad",
    keywords: [
      "mesh quality",
      "bad mesh",
      "poor quality",
      "distortion",
      "aspect ratio",
      "warpage",
      "skewness",
    ],
    color: "#4CAF50",
  },
  {
    name: "Presentation issue",
    keywords: [
      "presentation",
      "plot",
      "visualization",
      "display",
      "figure",
      "image",
    ],
    color: "#43A047",
  },
  {
    name: "Legend issue",
    keywords: ["legend", "color bar", "scale", "range", "contour"],
    color: "#388E3C",
  },
  {
    name: "Results data issue",
    keywords: ["results", "data", "output", "values", "incorrect results"],
    color: "#2E7D32",
  },
  {
    name: "Documentation Error",
    keywords: [
      "documentation",
      "doc",
      "report",
      "description",
      "text",
      "explanation",
      "missing info",
    ],
    color: "#1B5E20",
  },
  {
    name: "Spelling and grammar",
    keywords: ["spelling", "grammar", "typo", "language", "text error"],
    color: "#66BB6A",
  },
  {
    name: "Incorrect load combinations",
    keywords: ["load combination", "load case", "combination", "factored load"],
    color: "#81C784",
  },
  {
    name: "Missing required data",
    keywords: ["missing data", "data", "required", "information", "incomplete"],
    color: "#A5D6A7",
  },
  {
    name: "Incorrect acceptance criteria",
    keywords: [
      "acceptance criteria",
      "criteria",
      "limits",
      "allowable",
      "specification",
      "incorrect",
    ],
    color: "#C8E6C9",
  },
];

async function loadCategories() {
  try {
    console.log("🔄 Connecting to MongoDB...");
    await mongoose.connect(
      process.env.MONGO_DB_URI || "mongodb://localhost:27017/qrp"
    );
    console.log("✅ Connected to MongoDB");

    console.log("🔍 Finding template...");
    let template = await Template.findOne();

    if (!template) {
      console.log("⚠️ No template found, creating new one...");
      template = new Template({
        stage1: [],
        stage2: [],
        stage3: [],
        defectCategories: defaultCategories,
      });
    } else {
      console.log("✅ Template found");
      console.log(`📊 Current categories: ${template.defectCategories.length}`);
      template.defectCategories = defaultCategories;
    }

    console.log("💾 Saving 41 default categories to template...");
    await template.save();
    console.log("✅ Successfully loaded 41 default defect categories!");

    console.log("\n📋 Categories loaded:");
    defaultCategories.forEach((cat, idx) => {
      console.log(`${idx + 1}. ${cat.name} (${cat.keywords.length} keywords)`);
    });

    process.exit(0);
  } catch (error) {
    console.error("❌ Error loading categories:", error);
    process.exit(1);
  }
}

loadCategories();

