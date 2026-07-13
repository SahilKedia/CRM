const express = require("express");
const router = express.Router();

const {
  signup,
  login,
  employeeSendOtp,
  employeeVerifyOtp,
  getAllAdmins,
  updateAdmin,
  deleteAdmin,
} = require("../controllers/authController");

// ✅ CORRECT import for the middleware
const { protect, restrictTo } = require("../middleware/auth");
// Routes
router.post("/signup", signup);
router.post("/login", login);
router.post("/employee/send-otp", employeeSendOtp);
router.post("/employee/verify-otp", employeeVerifyOtp);

// Admin management routes (only superadmin)
router.get("/admins", protect, restrictTo("superadmin"), getAllAdmins);
router.put("/admins/:id", protect, restrictTo("superadmin"), updateAdmin);
router.delete("/admins/:id", protect, restrictTo("superadmin"), deleteAdmin);

module.exports = router;