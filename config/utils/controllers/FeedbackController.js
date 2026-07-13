// controllers/feedbackController.js
const crypto = require("crypto");
const Feedback = require("../models/Feedback");
const Customer = require("../models/Customer");
const { sendFeedbackEmail } = require("../utils/mailer");

// Called internally after customer is added
exports.createAndSendFeedbackRequest = async (customer) => {
  if (!customer.email) return; // no email, skip

  const token = crypto.randomBytes(20).toString("hex");

  await Feedback.create({
    customer: customer._id,
    branch: customer.branch,
    token,
  });

  const feedbackLink = `${process.env.FRONTEND_URL}/feedback/${token}`;

  try {
    await sendFeedbackEmail(customer.email, customer.name, feedbackLink);
  } catch (err) {
    console.error("❌ Failed to send feedback email:", err.message);
    // don't throw — customer creation should not fail because of email issue
  }
};

// GET feedback form data by token
exports.getFeedbackByToken = async (req, res) => {
  try {
    const { token } = req.params;
    const feedback = await Feedback.findOne({ token }).populate("customer", "name branch");

    if (!feedback) {
      return res.status(404).json({ success: false, message: "Invalid or expired link" });
    }
    if (feedback.status === "submitted") {
      return res.status(400).json({ success: false, message: "Feedback already submitted" });
    }

    res.json({
      success: true,
      data: {
        customerName: feedback.customer.name,
        branch: feedback.branch,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST submit feedback
exports.submitFeedback = async (req, res) => {
  try {
    const { token } = req.params;
    const { rating, comments } = req.body;

    const feedback = await Feedback.findOne({ token });
    if (!feedback) {
      return res.status(404).json({ success: false, message: "Invalid or expired link" });
    }
    if (feedback.status === "submitted") {
      return res.status(400).json({ success: false, message: "Feedback already submitted" });
    }

    feedback.rating = rating;
    feedback.comments = comments;
    feedback.status = "submitted";
    feedback.submittedAt = new Date();
    await feedback.save();

    res.json({ success: true, message: "Thank you for your feedback!" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};