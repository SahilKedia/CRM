const Employee = require("../models/Employee");

// Add Employee (admin only)
exports.addEmployee = async (req, res) => {
  try {
    let {
      name,
      email,
      phone,
      department,
      address,
      emergencyContact,
      branch,
    } = req.body;

    // Branch admin can only add employees to their own branch
    if (req.user && req.user.role === "admin" && req.user.branch) {
      branch = req.user.branch.toString();
    }

    // Trim values
    name = name?.trim();
    email = email?.trim();
    phone = phone?.trim();
    department = department?.trim();
    address = address?.trim();
    emergencyContact = emergencyContact?.trim();
    branch = branch?.trim();

    // Convert empty email to undefined
    if (!email) {
      email = undefined;
    }

    // Required fields
    if (!name) {
      return res.status(400).json({
        success: false,
        message: "Name is required",
      });
    }

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    if (!department) {
      return res.status(400).json({
        success: false,
        message: "Department is required",
      });
    }

    if (!branch) {
      return res.status(400).json({
        success: false,
        message: "Branch is required",
      });
    }

    // Phone must be unique
    const existingPhone = await Employee.findOne({ phone });
    if (existingPhone) {
      return res.status(400).json({
        success: false,
        message: "Employee with this phone number already exists",
      });
    }

    // Check email only if provided
    if (email) {
      const existingEmail = await Employee.findOne({
        email: email.toLowerCase(),
      });

      if (existingEmail) {
        return res.status(400).json({
          success: false,
          message: "Employee with this email already exists",
        });
      }
    }

    const employee = new Employee({
      name,
      phone,
      department,
      branch,
      address: address || "",
      emergencyContact: emergencyContact || "",
    });

    // Add email only if provided
    if (email) {
      employee.email = email.toLowerCase();
    }

    await employee.save();

    res.status(201).json({
      success: true,
      message: "Employee Added Successfully",
      data: employee,
    });

  } catch (err) {
    console.error("❌ Error adding employee:", err);

    if (err.code === 11000) {
      const field = Object.keys(err.keyPattern)[0];

      return res.status(400).json({
        success: false,
        message: `${field} already exists`,
      });
    }

    res.status(500).json({
      success: false,
      message: err.message || "Failed to add employee",
    });
  }
};
// Get Employees - branch-scoped for branch-admins, all for super-admin
exports.getEmployees = async (req, res) => {
  try {
    const filter = {};

    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch.toString();
    } else if (req.query.branch) {
      // Super admin can optionally filter by branch via ?branch=xxx
      filter.branch = req.query.branch;
    }

    const employees = await Employee.find(filter).sort({ createdAt: -1 });
    res.json({
      success: true,
      data: employees,
    });
  } catch (err) {
    console.error('❌ Error fetching employees:', err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch employees",
    });
  }
};

// Update Employee (admin only)
exports.updateEmployee = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Remove salary if it exists in the request (not needed)
    delete updateData.salary;

    // Validate branch for branch-admin
    if (req.user && req.user.role === "admin" && req.user.branch) {
      // Check if employee belongs to admin's branch
      const employee = await Employee.findById(id);
      if (!employee) {
        return res.status(404).json({
          success: false,
          message: "Employee not found",
        });
      }
      if (employee.branch !== req.user.branch.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only update employees in your branch",
        });
      }
      // Remove branch from updateData to prevent changing branch
      delete updateData.branch;
    }

    const employee = await Employee.findByIdAndUpdate(
      id,
      updateData,
      {
        new: true,
        runValidators: true,
      }
    );

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "Employee not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Employee Updated Successfully",
      data: employee,
    });
  } catch (err) {
    console.error('❌ Error updating employee:', err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to update employee",
    });
  }
};

// Delete Employee (admin only)
exports.deleteEmployee = async (req, res) => {
  try {
    const { id } = req.params;

    // Validate branch for branch-admin
    if (req.user && req.user.role === "admin" && req.user.branch) {
      const employee = await Employee.findById(id);
      if (!employee) {
        return res.status(404).json({
          success: false,
          message: "Employee not found",
        });
      }
      if (employee.branch !== req.user.branch.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only delete employees in your branch",
        });
      }
    }

    const employee = await Employee.findByIdAndDelete(id);

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "Employee not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Employee Deleted Successfully",
    });
  } catch (err) {
    console.error('❌ Error deleting employee:', err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to delete employee",
    });
  }
};