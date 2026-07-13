const mongoose = require("mongoose");

const employeeSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },

    // Optional email
    email: {
      type: String,
      trim: true,
      lowercase: true,
      unique: true,
      sparse: true,
      default: undefined, // Don't store null or ""
      validate: {
        validator: function (value) {
          if (!value) return true; // allow empty
          return /\S+@\S+\.\S+/.test(value);
        },
        message: "Please enter a valid email",
      },
    },

    phone: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },

    photo: {
      type: String,
      default: "",
    },

    department: {
      type: String,
      required: true,
    },

    branch: {
      type: String,
      required: true,
      trim: true,
    },

    address: {
      type: String,
      default: "",
    },

    emergencyContact: {
      type: String,
      default: "",
    },

    otp: {
      type: String,
      select: false,
    },

    otpExpiry: {
      type: Date,
      select: false,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Employee", employeeSchema);