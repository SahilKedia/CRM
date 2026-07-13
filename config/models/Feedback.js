// models/Feedback.js
const mongoose = require("mongoose");

const feedbackSchema = new mongoose.Schema(
  {
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
      required: true,
    },
    branch: { type: String, trim: true },
    token: { type: String, required: true, unique: true },
    status: {
      type: String,
      enum: ["pending", "submitted", "expired"],
      default: "pending",
    },
    rating: { type: Number, min: 1, max: 5 },
    comments: { type: String, trim: true },
    submittedAt: { type: Date },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Feedback", feedbackSchema);