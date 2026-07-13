const express = require("express");
const router = express.Router();
const { protect, restrictTo } = require("../middleware/auth");

const {
  addEmployee,
  getEmployees,
  updateEmployee,
  deleteEmployee,
} = require("../controllers/employeeController");

// All employee management routes require login.
// Only admins can add/update/delete employees.
router.post("/", protect, restrictTo("admin"), addEmployee);
router.get("/", protect, getEmployees);
router.put("/:id", protect, restrictTo("admin"), updateEmployee);
router.delete("/:id", protect, restrictTo("admin"), deleteEmployee);

module.exports = router;
