const mongoose = require("mongoose");

// Sub‑schema for each visit in the visits array
const VisitSchema = new mongoose.Schema(
  {
    visitNumber: {
      type: Number,
      required: true,
    },
    visitDate: {
      type: Date,
      default: Date.now,
    },
    purposeOfVisit: {
      type: String,
      trim: true,
    },
    // Jewelry details
    gold: {
      type: String,
      trim: true,
    },
    diamond: {
      type: String,
      trim: true,
    },
    polki: {
      type: String,
      trim: true,
    },
    // Image URLs (stored as arrays of strings)
    goldImages: [String],
    diamondImages: [String],
    polkiImages: [String],
    requirement: {
      type: String,
      trim: true,
    },
    // approval: {
    //   type: String,
    //   enum: ["pending", "approved", "rejected"],
    //   default: "pending",
    // },
    // conclusion: {
    //   type: String,
    //   enum: ["Pending", "Sold", "Not Interested", "Follow-up"],
    //   default: "Pending",
    // },
      requirement: {
  type: String,
  trim: true,
},
requirementStatus: {
  type: String,
  enum: ["none", "pending", "fulfilled"],
  default: "none",
},
requirementFulfilledAt: {
  type: Date,
  default: null,
},
conclusion: {
  type: String,
  enum: [
    "pending",
    "sold",
    "just see",
    "shortlisted",
    "on approval",
    "on order",
  ],
  default: "pending",
},
    whoAttend: {
      type: String,
      trim: true,
    },
    helper: {
      type: String,
      trim: true,
    },
    // Reminder specific to this visit (optional)
    reminder: {
      date: Date,
      note: String,
      status: {
        type: String,
        enum: ["pending", "completed"],
        default: "pending",
      },
      completedAt: Date,
    },
  },
  {
    _id: false, // We don't need a separate _id for each visit; use visitNumber as identifier
    timestamps: true, // Adds createdAt and updatedAt for each visit
  }
);

const CustomerSchema = new mongoose.Schema(
  {
    // ====================
    // Personal Information (common for all visits)
    // ====================

    customerImage: {
     type: String,
     default: undefined,
    },
    name: {
      type: String,
      required: [true, "Customer name is required"],
      trim: true,
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      match: [/\S+@\S+\.\S+/, "Please enter a valid email"],
    },
    phone: {
      type: String,
      trim: true,
    },
    address: {
      type: String,
      trim: true,
    },
    birthday: {
      type: String, // Format: "DD-MM" (e.g., "15-Aug")
      trim: true,
    },
    anniversary: {
      type: String, // Format: "DD-MM"
      trim: true,
    },
    profession: {
      type: String,
      trim: true,
    },
    community: {
      type: String,
      trim: true,
    },
    // Reference / referral
    referredBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Customer",
    },
    referenceNote: {
      type: String,
      trim: true,
    },
    // ====================
    // Branch & Assignment
    // ====================
    branch: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Branch",
      required: true,
    },
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Employee",
      required: true,
    },
    // ====================
    // Visits Array – all visits are stored here
    // ====================
    visits: [VisitSchema],

    // ====================
    // Top‑level fields mirroring the latest visit (for backward compatibility)
    // ====================
    visitDate: Date,
    purposeOfVisit: String,
    gold: String,
    diamond: String,
    polki: String,
    goldImages: [String],
    diamondImages: [String],
    polkiImages: [String],
    requirement: String,
    // approval: {
    //   type: String,
    //   enum: ["pending", "approved", "rejected"],
    //   default: "pending",
    // },
    // conclusion: {
    //   type: String,
    //   enum: ["Pending", "Sold", "Not Interested", "Follow-up"],
    //   default: "Pending",
    // },
conclusion: {
  type: String,
  enum: [
    "pending",
    "sold",
    "just see",
    "shortlisted",
    "on approval",
    "on order",
  ],
  default: "pending",
},
    whoAttend: String,
    helper: String,

    // Top‑level reminder – can be used if needed, but we mostly use per‑visit reminders.
    reminder: {
      date: Date,
      note: String,
      status: {
        type: String,
        enum: ["pending", "completed"],
        default: "pending",
      },
      completedAt: Date,
    },

    // ====================
    // Meta & Classification
    // ====================
    numberOfVisit: {
      type: Number,
      default: 0,
    },
    customerClass: {
      type: String,
      enum: ["Regular", "VIP", "Loyal", "Big Spender"],
      default: "Regular",
    },
    manualClassOverride: {
      type: String,
      enum: ["Regular", "VIP", "Loyal", "Big Spender"],
    },
  },
  {
    timestamps: true,
  }
);

// Index for faster queries
CustomerSchema.index({ branch: 1, phone: 1 });
CustomerSchema.index({ branch: 1, email: 1 });
CustomerSchema.index({ assignedTo: 1 });

module.exports = mongoose.model("Customer", CustomerSchema);