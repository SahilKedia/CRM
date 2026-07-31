const mongoose = require("mongoose");

const feedbackSchema = new mongoose.Schema(
  {
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
      required: false, // relaxed — WhatsApp webhook may not always match a customer record
    },

    customerName: String,
    customerPhone: {
      type: String,
      index: true, // looked up frequently in the WhatsApp webhook
    },

    branch: {
      type: String,
      trim: true,
    },

    rating: {
      type: Number,
      min: 1,
      max: 5,
    },

    comments: {
      type: String,
      trim: true,
    },

    source: {
      type: String,
      enum: ["whatsapp"],
      default: "whatsapp",
    },

    // Used by the web-form link flow (feedbackController.js)
    token: {
      type: String,
      unique: true,
      sparse: true, // allows docs without a token (WhatsApp-only feedback)
    },

    // pending/submitted/expired = web-form flow
    // awaiting_reply = WhatsApp button-click flow, waiting on customer's text reply
    status: {
      type: String,
      enum: ["pending", "awaiting_reply", "submitted", "expired"],
      default: "pending",
    },

    submittedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Feedback", feedbackSchema);