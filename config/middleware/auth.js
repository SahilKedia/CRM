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

    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET);
    } catch (jwtErr) {
      // Distinguish expired vs invalid so the client can react correctly
      if (jwtErr.name === "TokenExpiredError") {
        return res.status(401).json({
          success: false,
          message: "Session expired. Please login again.",
        });
      }
      return res.status(401).json({
        success: false,
        message: "Invalid token. Please login again.",
      });
    }

    // Normalize role from token to avoid case-sensitivity issues (" Admin", "ADMIN", etc.)
    const tokenRole = (decoded.role || "").toString().trim().toLowerCase();

    if (tokenRole === "admin" || tokenRole === "superadmin") {
      const user = await User.findById(decoded.id).select("-password");
      if (!user) {
        return res.status(401).json({ success: false, message: "User not found" });
      }

      // Trust the DB's current role, not the (possibly stale) token role,
      // but normalize it the same way so comparisons never break on casing.
      const dbRole = (user.role || "").toString().trim().toLowerCase();

      req.user = {
        id: user._id,
        role: dbRole || tokenRole, // fallback to token role if DB role missing
        branch: user.branch || null,
        name: user.name,
      };
    } else if (tokenRole === "employee") {
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
  // Normalize the allowed roles once, up front
  const allowed = roles.map((r) => r.toString().trim().toLowerCase());

  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(403).json({
        success: false,
        message: "You do not have permission to perform this action",
      });
    }

    const userRole = req.user.role.toString().trim().toLowerCase();

    // superadmin automatically satisfies any check that allows "admin"
    const hasAccess =
      allowed.includes(userRole) ||
      (userRole === "superadmin" && allowed.includes("admin"));

    if (!hasAccess) {
      return res.status(403).json({
        success: false,
        message: "You do not have permission to perform this action",
      });
    }

    next();
  };
};