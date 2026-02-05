// utils/fixRoleIndexes.js
import mongoose from "mongoose";
import { Role } from "../models/roles.models.js";

export const fixRoleIndexes = async () => {
  console.log("🔧 Checking and initializing roles...");

  try {
    // Get the current database name
    const dbName = mongoose.connection.db.databaseName;
    console.log(`📊 Working on database: ${dbName}`);

    // Check if roles already exist
    const existingRoles = await Role.find({});

    if (existingRoles.length > 0) {
      console.log(`✅ Found ${existingRoles.length} existing roles - keeping them:`);
      existingRoles.forEach(role => {
        console.log(`   - ${role.role_name} (ID: ${role._id})`);
      });

      // Only ensure we have all three required roles
      const existingRoleNames = existingRoles.map(r => r.role_name);
      const requiredRoles = ["Executor", "Reviewer", "TeamLeader"];
      const missingRoles = requiredRoles.filter(r => !existingRoleNames.includes(r));

      if (missingRoles.length > 0) {
        console.log(`📝 Creating missing roles: ${missingRoles.join(', ')}`);
        const roleDescriptions = {
          "Executor": "Handles assigned tasks",
          "Reviewer": "Reviews and approves work",
          "TeamLeader": "Team Leader / Sectional department head"
        };

        for (const roleName of missingRoles) {
          await Role.create({
            role_name: roleName,
            description: roleDescriptions[roleName]
          });
          console.log(`✅ Created missing role: ${roleName}`);
        }
      }

      return; // Roles exist, nothing more to do
    }

    // If no roles exist, create them from scratch
    console.log("📝 No roles found, creating default roles...");

    // Ensure indexes are created
    console.log("🔨 Creating indexes...");
    await Role.createIndexes();
    console.log("✅ Indexes created");

    // Seed the default roles
    const defaultRoles = [
      { role_name: "Executor", description: "Handles assigned tasks" },
      { role_name: "Reviewer", description: "Reviews and approves work" },
      { role_name: "TeamLeader", description: "Team Leader / Sectional department head" },
    ];

    for (const roleData of defaultRoles) {
      await Role.create(roleData);
      console.log(`✅ Created role: ${roleData.role_name}`);
    }

    // Verify
    const allRoles = await Role.find({});
    console.log(`\n✅ Final verification - ${allRoles.length} roles in database:`);
    allRoles.forEach(role => {
      console.log(`   - ${role.role_name} (ID: ${role._id})`);
    });

  } catch (error) {
    console.error("❌ Error initializing roles:", error);
    throw error;
  }
};
