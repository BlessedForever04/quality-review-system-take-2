// utils/seedRoles.js
import { Role } from "../models/roles.models.js";

export const seedRoles = async () => {
  const defaultRoles = [
    { role_id: 1, role_name: "Executor", description: "Handles assigned tasks" },
    { role_id: 2, role_name: "Reviewer", description: "Reviews and approves work" },
    { role_id: 3, role_name: "SDH", description: "Sectional department head" },
  ];

  for (const role of defaultRoles) {
    const exists = await Role.findOne({ role_name: role.role_name });
    if (!exists) {
      await Role.create(role);
      console.log(`✅ Role '${role.role_name}' created`);
    }
  }
};
