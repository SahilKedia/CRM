const jwt = require("jsonwebtoken");
const User = require("../models/User");
const Employee = require("../models/Employee");

exports.protect = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Not authorized. Please login again.",
      });
    }

    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    if (decoded.role === "admin" || decoded.role === "superadmin") {
      const user = await User.findById(decoded.id).select("-password");
      if (!user) {
        return res.status(401).json({ success: false, message: "User not found" });
      }
      req.user = {
        id: user._id,
        role: user.role,
        branch: user.branch || null,
        name: user.name,
      };
    } else if (decoded.role === "employee") {
      const employee = await Employee.findById(decoded.id);
      if (!employee) {
        return res.status(401).json({ success: false, message: "Employee not found" });
      }
      req.user = {
        id: employee._id,
        role: "employee",
        branch: employee.branch,
        name: employee.name,
      };
    } else {
      return res.status(401).json({ success: false, message: "Invalid role in token" });
    }

    next();
  } catch (err) {
    console.error("Auth error:", err.message);
    return res.status(401).json({
      success: false,
      message: "Session expired or invalid. Please login again.",
    });
  }
};

exports.restrictTo = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: "You do not have permission to perform this action",
      });
    }
    next();
  };
};