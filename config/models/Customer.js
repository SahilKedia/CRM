const mongoose = require("mongoose");

// Sub-schema for a single jewelry item (gold, diamond, or polki)
const JewelryItemSchema = new mongoose.Schema(
  {
    description: {
      type: String, // e.g. "Ring", "Necklace", "Bangle set"
      trim: true,
      required: true,
    },
    weight: {
      type: String, // optional free text, e.g. "10g", "2.5ct"
      trim: true,
    },
    images: [String],
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
    remarks: {
      type: String,
      trim: true,
    },
  },
  {
    _id: true, // each item gets its own id so it can be updated/removed individually
    timestamps: true,
  }
);

// Sub-schema for each visit in the visits array
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

    // Multiple items per category, each with its own conclusion
    goldItems: [JewelryItemSchema],
    diamondItems: [JewelryItemSchema],
    polkiItems: [JewelryItemSchema],

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
    whoAttend: {
      type: String,
      trim: true,
    },
    helper: {
      type: String,
      trim: true,
    },
    // Per-visit reminder (routes/customerRoutes.js reads/writes visit.reminder —
    // this field was missing before, so those endpoints were throwing).
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
    _id: false, // use visitNumber as identifier, not a separate _id
    timestamps: true,
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
    additionalInfo: {
      type: String,
      trim: true,
      default: undefined,
    },
    additionalInfoImage: {
      type: String,
      default: undefined,
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
    // Top-level fields mirroring the latest visit (for backward compatibility)
    // ====================
    visitDate: Date,
    purposeOfVisit: String,
    goldItems: [JewelryItemSchema],
    diamondItems: [JewelryItemSchema],
    polkiItems: [JewelryItemSchema],
    requirement: String,
    whoAttend: String,
    helper: String,

    // Top-level reminder – this is the ONLY reminder used by the app.
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