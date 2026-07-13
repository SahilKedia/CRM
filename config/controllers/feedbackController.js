const crypto = require("crypto");
const Feedback = require("../models/Feedback");
const Customer = require("../models/Customer");
const { sendFeedbackEmail } = require("../utils/mailer");
const googleReviewLinks = require("../config/googleReviewLinks");

// -----------------------------------------
// Called internally after a customer is added
// -----------------------------------------
exports.createAndSendFeedbackRequest = async (customer) => {
  try {
    if (!customer.email) return;

    const token = crypto.randomBytes(20).toString("hex");

    await Feedback.create({
      customer: customer._id,
      branch: customer.branch,
      token,
    });

    const feedbackLink = `${process.env.FRONTEND_URL}/feedback/${token}`;
    await sendFeedbackEmail(customer.email, customer.name, feedbackLink);
  } catch (err) {
    console.error("❌ Failed to create/send feedback request:", err.message);
  }
};

// -----------------------------------------
// GET /api/feedback/:token
// Get feedback form data by token (Public)
// -----------------------------------------
exports.getFeedbackByToken = async (req, res) => {
  try {
    const { token } = req.params;

    const feedback = await Feedback.findOne({ token }).populate(
      "customer",
      "name email branch"
    );

    if (!feedback) {
      return res.status(404).json({
        success: false,
        message: "Invalid or expired link",
      });
    }

    if (feedback.status === "submitted") {
      return res.status(400).json({
        success: false,
        message: "Feedback already submitted",
      });
    }

    res.json({
      success: true,
      data: {
        customerName: feedback.customer.name,
        customerEmail: feedback.customer.email,
        branch: feedback.branch,
        googleReviewLink: googleReviewLinks[feedback.branch] || googleReviewLinks.default,
      },
    });
  } catch (err) {
    console.error("❌ Error fetching feedback by token:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Something went wrong",
    });
  }
};

// -----------------------------------------
// POST /api/feedback/:token
// Submit feedback (Public)
// -----------------------------------------
exports.submitFeedback = async (req, res) => {
  try {
    const { token } = req.params;
    const { rating, comments } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: "Please provide a valid rating (1-5)",
      });
    }

    const feedback = await Feedback.findOne({ token });

    if (!feedback) {
      return res.status(404).json({
        success: false,
        message: "Invalid or expired link",
      });
    }

    if (feedback.status === "submitted") {
      return res.status(400).json({
        success: false,
        message: "Feedback already submitted",
      });
    }

    feedback.rating = rating;
    feedback.comments = comments?.trim() || "";
    feedback.status = "submitted";
    feedback.submittedAt = new Date();
    await feedback.save();

    res.json({
      success: true,
      message: "Thank you for your feedback!",
    });
  } catch (err) {
    console.error("❌ Error submitting feedback:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Something went wrong",
    });
  }
};

// -----------------------------------------
// GET /api/feedback
// Get all feedback with filters (Admin only)
// -----------------------------------------
exports.getAllFeedback = async (req, res) => {
  try {
    const filter = {};

    // If user is admin with a specific branch, only show their branch
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    }

    // Filter by status if provided
    if (req.query.status && req.query.status !== "all") {
      filter.status = req.query.status;
    }

    // Filter by branch if provided (only for super admin or if branch filter is passed)
    if (req.query.branch && req.query.branch !== "all") {
      // If user is branch admin, they can only see their branch
      if (req.user.role === "admin" && req.user.branch) {
        if (req.user.branch.toString() !== req.query.branch) {
          return res.status(403).json({
            success: false,
            message: "You don't have permission to view other branches",
          });
        }
      }
      filter.branch = req.query.branch;
    }

    // Search by customer name, email, or comments
    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search, "i");
      
      // First find customers matching the search
      const customers = await Customer.find({
        $or: [
          { name: searchRegex },
          { email: searchRegex },
          { phone: searchRegex }
        ]
      }).select("_id");

      const customerIds = customers.map(c => c._id);
      
      filter.$or = [
        { customer: { $in: customerIds } },
        { comments: searchRegex },
        { branch: searchRegex }
      ];
    }

    const feedbackList = await Feedback.find(filter)
      .populate("customer", "name email phone branch")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: feedbackList,
    });
  } catch (err) {
    console.error("❌ Error fetching feedback list:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch feedback",
    });
  }
};

// -----------------------------------------
// GET /api/feedback/stats
// Get feedback statistics (Admin only)
// -----------------------------------------
exports.getFeedbackStats = async (req, res) => {
  try {
    const filter = {};

    // If user is admin with a specific branch, only their branch
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    }

    // Get counts
    const total = await Feedback.countDocuments(filter);
    const submitted = await Feedback.countDocuments({ ...filter, status: "submitted" });
    const pending = await Feedback.countDocuments({ ...filter, status: "pending" });
    const expired = await Feedback.countDocuments({ ...filter, status: "expired" });

    // Calculate average rating
    const avgResult = await Feedback.aggregate([
      { $match: { ...filter, status: "submitted", rating: { $exists: true, $ne: null } } },
      { $group: { _id: null, avg: { $avg: "$rating" } } }
    ]);

    const averageRating = avgResult.length > 0 ? avgResult[0].avg : 0;

    // Get rating distribution
    const distribution = await Feedback.aggregate([
      { $match: { ...filter, status: "submitted", rating: { $exists: true, $ne: null } } },
      { $group: { _id: "$rating", count: { $sum: 1 } } },
      { $sort: { _id: 1 } }
    ]);

    const ratingDistribution = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0
    };
    distribution.forEach(item => {
      ratingDistribution[item._id] = item.count;
    });

    // Get monthly trend (last 6 months)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

    const monthlyTrend = await Feedback.aggregate([
      { 
        $match: { 
          ...filter, 
          status: "submitted",
          submittedAt: { $gte: sixMonthsAgo }
        } 
      },
      {
        $group: {
          _id: {
            year: { $year: "$submittedAt" },
            month: { $month: "$submittedAt" }
          },
          count: { $sum: 1 },
          avgRating: { $avg: "$rating" }
        }
      },
      { $sort: { "_id.year": 1, "_id.month": 1 } }
    ]);

    res.json({
      success: true,
      data: {
        total,
        submitted,
        pending,
        expired,
        averageRating: parseFloat(averageRating.toFixed(1)),
        ratingDistribution,
        monthlyTrend: monthlyTrend.map(item => ({
          month: `${item._id.month}/${item._id.year}`,
          count: item.count,
          avgRating: parseFloat(item.avgRating.toFixed(1))
        }))
      }
    });
  } catch (err) {
    console.error("❌ Error fetching stats:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch stats",
    });
  }
};

// -----------------------------------------
// GET /api/feedback/:id
// Get single feedback by ID (Admin only)
// -----------------------------------------
exports.getFeedbackById = async (req, res) => {
  try {
    const { id } = req.params;

    const feedback = await Feedback.findById(id)
      .populate("customer", "name email phone branch");

    if (!feedback) {
      return res.status(404).json({
        success: false,
        message: "Feedback not found",
      });
    }

    // Check if user has permission to view this feedback
    if (req.user.role === "admin" && req.user.branch) {
      if (feedback.branch !== req.user.branch) {
        return res.status(403).json({
          success: false,
          message: "You don't have permission to view this feedback",
        });
      }
    }

    res.json({
      success: true,
      data: feedback,
    });
  } catch (err) {
    console.error("❌ Error fetching feedback:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch feedback",
    });
  }
};

// -----------------------------------------
// GET /api/feedback/branch/:branch
// Get feedback by specific branch (Admin only)
// -----------------------------------------
exports.getFeedbackByBranch = async (req, res) => {
  try {
    const { branch } = req.params;
    
    // Check if user has access to this branch
    if (req.user.role === "admin" && req.user.branch) {
      if (req.user.branch.toString() !== branch) {
        return res.status(403).json({
          success: false,
          message: "You don't have permission to view this branch",
        });
      }
    }

    const feedbackList = await Feedback.find({ branch })
      .populate("customer", "name email phone")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: feedbackList,
    });
  } catch (err) {
    console.error("❌ Error fetching branch feedback:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch feedback",
    });
  }
};

// -----------------------------------------
// GET /api/feedback/customer/:customerId
// Get feedback by customer ID (Admin only)
// -----------------------------------------
exports.getFeedbackByCustomer = async (req, res) => {
  try {
    const { customerId } = req.params;

    const feedbackList = await Feedback.find({ customer: customerId })
      .populate("customer", "name email phone")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: feedbackList,
    });
  } catch (err) {
    console.error("❌ Error fetching customer feedback:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch feedback",
    });
  }
};

// -----------------------------------------
// DELETE /api/feedback/:id
// Delete feedback (Admin only)
// -----------------------------------------
exports.deleteFeedback = async (req, res) => {
  try {
    const { id } = req.params;

    const feedback = await Feedback.findById(id);
    if (!feedback) {
      return res.status(404).json({
        success: false,
        message: "Feedback not found",
      });
    }

    // Check if user has permission to delete this feedback
    if (req.user.role === "admin" && req.user.branch) {
      if (feedback.branch !== req.user.branch) {
        return res.status(403).json({
          success: false,
          message: "You don't have permission to delete this feedback",
        });
      }
    }

    await feedback.deleteOne();

    res.json({
      success: true,
      message: "Feedback deleted successfully",
    });
  } catch (err) {
    console.error("❌ Error deleting feedback:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to delete feedback",
    });
  }
};

// -----------------------------------------
// PUT /api/feedback/:id/status
// Update feedback status (Admin only)
// -----------------------------------------
exports.updateFeedbackStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!["pending", "submitted", "expired"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid status value",
      });
    }

    const feedback = await Feedback.findById(id);
    if (!feedback) {
      return res.status(404).json({
        success: false,
        message: "Feedback not found",
      });
    }

    // Check if user has permission to update this feedback
    if (req.user.role === "admin" && req.user.branch) {
      if (feedback.branch !== req.user.branch) {
        return res.status(403).json({
          success: false,
          message: "You don't have permission to update this feedback",
        });
      }
    }

    feedback.status = status;
    await feedback.save();

    res.json({
      success: true,
      message: "Feedback status updated successfully",
      data: feedback,
    });
  } catch (err) {
    console.error("❌ Error updating feedback status:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to update feedback status",
    });
  }
};