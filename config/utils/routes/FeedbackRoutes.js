// routes/feedbackRoutes.js
const express = require("express");
const router = express.Router();
const {
  getFeedbackByToken,
  submitFeedback,
  getAllFeedback,
} = require("../controllers/feedbackController");

const authMiddleware = require("../middleware/authMiddleware"); // 👈 apna existing auth middleware path daalo

// -----------------------------------------
// PROTECTED route — admin/employee login required
// Order matters: ye specific route pehle rakho, warna "/" wala
// galti se ":token" route se match ho sakta hai in some setups
// -----------------------------------------
router.get("/", authMiddleware, getAllFeedback);

// -----------------------------------------
// PUBLIC routes — no auth, customer email link se access karta hai
// -----------------------------------------
router.get("/:token", getFeedbackByToken);
router.post("/:token", submitFeedback);

module.exports = router;