// utils/fixRoleIndexes.js
import mongoose from "mongoose";
import { Role } from "../models/roles.models.js";

export const fixRoleIndexes = async () => {
  console.log("🔧 Fixing role indexes and duplicates...");
  
  try {
    // Get the current database name
    const dbName = mongoose.connection.db.databaseName;
    console.log(`📊 Working on database: ${dbName}`);
    
    // Drop all indexes on the roles collection
    console.log("🗑️  Dropping existing indexes...");
    try {
      await Role.collection.dropIndexes();
      console.log("✅ Indexes dropped");
    } catch (err) {
      console.log("⚠️  No indexes to drop or error:", err.message);
    }
    
    // Delete all existing roles (we'll recreate them)
    const deletedCount = await Role.deleteMany({});
    console.log(`🗑️  Deleted ${deletedCount.deletedCount} existing roles`);
    
    // Recreate indexes
    console.log("🔨 Creating indexes...");
    await Role.createIndexes();
    console.log("✅ Indexes created");
    
    // Seed the correct roles
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
    console.error("❌ Error fixing role indexes:", error);
    throw error;
  }
};
