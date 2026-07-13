const express = require("express");
const router = express.Router();
const {
  getFeedbackByToken,
  submitFeedback,
  getAllFeedback,
  getFeedbackStats,
  getFeedbackById,
  getFeedbackByBranch,
  getFeedbackByCustomer,
  deleteFeedback,
  updateFeedbackStatus,
} = require("../controllers/feedbackController");

const { protect, restrictTo } = require("../middleware/auth");

// ============================================
// PUBLIC ROUTES (No authentication required)
// ============================================
router.get("/:token", getFeedbackByToken);
router.post("/:token", submitFeedback);

// ============================================
// ADMIN ROUTES (Authentication required)
// ============================================
// All admin routes require authentication
router.use(protect);

// Restrict to admin only (not employees)
router.use(restrictTo("admin"));

// Get all feedback with filters
router.get("/", getAllFeedback);

// Get feedback statistics
router.get("/stats", getFeedbackStats);

// Get feedback by ID
router.get("/:id", getFeedbackById);

// Get feedback by branch
router.get("/branch/:branch", getFeedbackByBranch);

// Get feedback by customer
router.get("/customer/:customerId", getFeedbackByCustomer);

// Update feedback status
router.put("/:id/status", updateFeedbackStatus);

// Delete feedback
router.delete("/:id", deleteFeedback);

module.exports = router;