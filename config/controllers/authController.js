const User = require("../models/User");
const Employee = require("../models/Employee");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { sendOtpEmail } = require("../utils/mailer"); // 👈 changed — sendSMS hataya, mailer se sendOtpEmail import kiya

// Helper: generate a signed JWT for either an admin or an employee
const generateToken = (id, role) => {
  return jwt.sign({ id, role }, process.env.JWT_SECRET, { expiresIn: "7d" });
};

// ---------------------------------------------------------
// ADMIN SIGNUP  (name, email, password, branch [optional])
// ---------------------------------------------------------
// ---------------------------------------------------------
// SIGNUP (Super Admin / Admin / Employee)
// ---------------------------------------------------------
exports.signup = async (req, res) => {
  try {
    const { name, email, password, branch, role } = req.body;

    console.log("📦 Signup Request Body:", req.body);
    console.log("🎭 Role received from Flutter:", role);

    if (!name || !email || !password || !role) {
      return res.status(400).json({
        success: false,
        message: "Name, email, password and role are required",
      });
    }

    // Allowed roles
    const allowedRoles = ["superadmin", "admin", "employee"];

    if (!allowedRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role",
      });
    }

    // Branch is required for Admin & Employee only
    if ((role === "admin" || role === "employee") && !branch) {
      return res.status(400).json({
        success: false,
        message: "Branch is required for Admin and Employee",
      });
    }

    const userExists = await User.findOne({
      email: email.trim().toLowerCase(),
    });

    if (userExists) {
      return res.status(400).json({
        success: false,
        message: "User already exists",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await User.create({
      name,
      email: email.trim().toLowerCase(),
      password: hashedPassword,
      role,
      branch: role === "superadmin" ? null : branch,
    });

    console.log("💾 Saved user document:", user);

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
    console.log("❌ Signup Error:", err);

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

    const user = await User.findOne({
      email: email.trim().toLowerCase(),
    }).populate("branch", "name");

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

    const token = generateToken(user._id, user.role);

    res.status(200).json({
      success: true,
      message: "Login Successful",
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        branch: user.branch
            ? {
                id: user.branch._id,
                name: user.branch.name,
              }
            : null,
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
// GET ADMIN COUNT
// ---------------------------------------------------------
// GET /api/admins
exports.getAllAdmins = async (req, res) => {
  try {
    // Only users with role 'admin' (not superadmin, not employee)
    const admins = await User.find({ role: 'admin' }).select('-password -__v');
    res.status(200).json({
      success: true,
      admins,
    });
  } catch (err) {
    console.error('❌ Error fetching admins:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch admins',
    });
  }
};

// PUT /api/admins/:id
exports.updateAdmin = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, email, password } = req.body;

    const admin = await User.findById(id);
    if (!admin) {
      return res.status(404).json({
        success: false,
        message: 'Admin not found',
      });
    }

    // Ensure the user is an admin (not superadmin or employee)
    if (admin.role !== 'admin') {
      return res.status(400).json({
        success: false,
        message: 'User is not an admin',
      });
    }

    // Update fields
    if (name) admin.name = name;
    if (email) admin.email = email.trim().toLowerCase();

    // If password provided, hash and update
    if (password) {
      const hashedPassword = await bcrypt.hash(password, 10);
      admin.password = hashedPassword;
    }

    await admin.save();

    res.status(200).json({
      success: true,
      message: 'Admin updated successfully',
      admin: {
        id: admin._id,
        name: admin.name,
        email: admin.email,
        role: admin.role,
        branch: admin.branch,
      },
    });
  } catch (err) {
    console.error('❌ Error updating admin:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to update admin',
    });
  }
};
// DELETE /api/admins/:id
exports.deleteAdmin = async (req, res) => {
  try {
    const { id } = req.params;

    const admin = await User.findById(id);
    if (!admin) {
      return res.status(404).json({
        success: false,
        message: 'Admin not found',
      });
    }

    if (admin.role !== 'admin') {
      return res.status(400).json({
        success: false,
        message: 'User is not an admin',
      });
    }

    await admin.deleteOne();

    res.status(200).json({
      success: true,
      message: 'Admin deleted successfully',
    });
  } catch (err) {
    console.error('❌ Error deleting admin:', err);
    res.status(500).json({
      success: false,
      message: 'Failed to delete admin',
    });
  }
};
// ---------------------------------------------------------
// EMPLOYEE LOGIN - STEP 1: Send OTP to employee's registered EMAIL
// ---------------------------------------------------------
exports.employeeSendOtp = async (req, res) => {
  try {
    const { email } = req.body; // 👈 changed from phone

    if (!email) {
      return res.status(400).json({
        success: false,
        message: "Email is required",
      });
    }

    const employee = await Employee.findOne({ email: email.trim().toLowerCase() }); // 👈 changed

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "No employee found with this email", // 👈 changed message
      });
    }

    // 6 digit OTP, valid for 5 minutes
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    employee.otp = otp;
    employee.otpExpiry = Date.now() + 5 * 60 * 1000;
    await employee.save();

    try {
      await sendOtpEmail(employee.email, employee.name, otp); // 👈 changed — email bhej rahe hain ab
    } catch (mailErr) {
      // SMTP config galat ho ya connection fail ho jaye to server crash na ho
      console.error("❌ OTP email send failed:", mailErr.message);

      // Development mein OTP response mein bhi bhej do taaki SMTP setup
      // ke bina bhi testing ho sake. Production mein ye hata dena.
      if (process.env.NODE_ENV !== "production") {
        return res.status(200).json({
          success: true,
          message: "Email could not be sent (dev mode) - OTP returned for testing",
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
      message: "OTP sent successfully to your email", // 👈 changed message
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
    const { email, otp } = req.body; // 👈 changed from phone

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        message: "Email and OTP are required", // 👈 changed message
      });
    }

    const employee = await Employee.findOne({ email: email.trim().toLowerCase() }).select(
      "+otp +otpExpiry"
    ); // 👈 changed

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "No employee found with this email", // 👈 changed message
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
        email: employee.email, // 👈 changed from phone
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