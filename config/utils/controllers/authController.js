const User = require("../models/User");
const Employee = require("../models/Employee");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { sendSMS } = require("../utils/sendSMS");

// Helper: generate a signed JWT for either an admin or an employee
const generateToken = (id, role) => {
  return jwt.sign({ id, role }, process.env.JWT_SECRET, { expiresIn: "7d" });
};

// ---------------------------------------------------------
// ADMIN SIGNUP  (name, email, password, branch [optional])
// Branch khali chodo to "super admin" ban jayega (saari branches).
// ---------------------------------------------------------
exports.signup = async (req, res) => {
  try {
    const { name, email, password, branch } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Name, email and password are required",
      });
    }

    const userExists = await User.findOne({ email });

    if (userExists) {
      return res.status(400).json({
        success: false,
        message: "User already exists",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await User.create({
      name,
      email,
      password: hashedPassword,
      role: "admin",
      branch: branch || null,
    });

    res.status(201).json({
      success: true,
      message: "Signup Successful",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        branch: user.branch,
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// ---------------------------------------------------------
// ADMIN LOGIN  (email + password)
// ---------------------------------------------------------
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required",
      });
    }

    const user = await User.findOne({ email });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: "Invalid Password",
      });
    }

    const token = generateToken(user._id, "admin");

    res.status(200).json({
      success: true,
      message: "Login Successful",
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: "admin",
        branch: user.branch,
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// ---------------------------------------------------------
// EMPLOYEE LOGIN - STEP 1: Send OTP to employee's registered phone
// ---------------------------------------------------------
exports.employeeSendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: "Phone number is required",
      });
    }

    const employee = await Employee.findOne({ phone });

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "No employee found with this phone number",
      });
    }

    // 6 digit OTP, valid for 5 minutes
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    employee.otp = otp;
    employee.otpExpiry = Date.now() + 5 * 60 * 1000;
    await employee.save();

    const message = `Your CRM login OTP is ${otp}. Valid for 5 minutes.`;

    try {
      await sendSMS(phone, message);
    } catch (smsErr) {
      // Twilio trial account / bad config vagera se SMS fail ho sakta hai.
      // Server crash na ho, isliye error ko yahin handle karo.
      console.error("SMS send failed:", smsErr.message);

      // Development mein OTP response mein bhi bhej do taaki Twilio setup
      // ke bina bhi testing ho sake. Production mein ye hata dena.
      if (process.env.NODE_ENV !== "production") {
        return res.status(200).json({
          success: true,
          message: "SMS could not be sent (dev mode) - OTP returned for testing",
          otp,
        });
      }

      return res.status(500).json({
        success: false,
        message: "Failed to send OTP. Please try again later.",
      });
    }

    res.status(200).json({
      success: true,
      message: "OTP sent successfully",
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

// ---------------------------------------------------------
// EMPLOYEE LOGIN - STEP 2: Verify OTP and issue token
// ---------------------------------------------------------
exports.employeeVerifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({
        success: false,
        message: "Phone number and OTP are required",
      });
    }

    const employee = await Employee.findOne({ phone }).select("+otp +otpExpiry");

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "No employee found with this phone number",
      });
    }

    if (!employee.otp || !employee.otpExpiry) {
      return res.status(400).json({
        success: false,
        message: "No OTP was requested. Please request an OTP first.",
      });
    }

    if (employee.otpExpiry < Date.now()) {
      return res.status(400).json({
        success: false,
        message: "OTP expired. Please request a new one.",
      });
    }

    if (employee.otp !== otp) {
      return res.status(400).json({
        success: false,
        message: "Invalid OTP",
      });
    }

    // OTP used - clear it so it can't be reused
    employee.otp = undefined;
    employee.otpExpiry = undefined;
    await employee.save();

    const token = generateToken(employee._id, "employee");

    res.status(200).json({
      success: true,
      message: "Login Successful",
      token,
      user: {
        id: employee._id,
        name: employee.name,
        phone: employee.phone,
        role: "employee",
        branch: employee.branch,
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};
