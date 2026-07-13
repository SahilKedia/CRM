const Employee = require("../models/Employee");

// Add Employee (admin only)
exports.addEmployee = async (req, res) => {
  try {
    const { name, email, phone, department, position, salary } = req.body;
    let { branch } = req.body;

    // Agar branch-admin (apni ek branch se bandha hua admin) hai, to employee
    // uski hi branch mein create hoga - dusri branch mein nahi bana sakta.
    if (req.user && req.user.role === "admin" && req.user.branch) {
      branch = req.user.branch;
    }

    if (!branch) {
      return res.status(400).json({
        success: false,
        message: "Branch is required",
      });
    }

    if (!name || !phone) {
      return res.status(400).json({
        success: false,
        message: "Name and phone are required",
      });
    }

    const employee = await Employee.create({
      name,
      email,
      phone,
      department,
      position,
      salary,
      branch,
    });

    res.status(201).json({
      success: true,
      message: "Employee Added",
      employee,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// Get Employees - branch-scoped for branch-admins, all for super-admin
exports.getEmployees = async (req, res) => {
  try {
    const filter = {};

    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    } else if (req.query.branch) {
      // Super admin can optionally filter by branch via ?branch=xxx
      filter.branch = req.query.branch;
    }

    const employees = await Employee.find(filter);
    res.json({
      success: true,
      employees,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// Update Employee (admin only)
exports.updateEmployee = async (req, res) => {
  try {
    const employee = await Employee.findByIdAndUpdate(
      req.params.id,
      req.body,
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
      employee,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// Delete Employee (admin only)
exports.deleteEmployee = async (req, res) => {
  try {
    const employee = await Employee.findByIdAndDelete(req.params.id);

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
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};
