const express = require("express");

const router = express.Router();

const {
  signup,
  login,
  employeeSendOtp,
  employeeVerifyOtp,
} = require("../controllers/authController");

// Admin auth
router.post("/signup", signup);
router.post("/login", login);

// Employee auth (phone + OTP via Twilio)
router.post("/employee/send-otp", employeeSendOtp);
router.post("/employee/verify-otp", employeeVerifyOtp);

module.exports = router;
