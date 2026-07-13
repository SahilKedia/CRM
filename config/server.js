require("dotenv").config();

const express = require("express");
const path = require("path");
const fs = require("fs");
const cors = require("cors");

const connectDB = require("./config/db");

const authRoutes = require("./routes/authRoutes");
const employeeRoutes = require("./routes/employeeRoutes");
const customerRoutes = require("./routes/customerRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const branchRoutes = require("./routes/branchRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const adminRoutes = require('./routes/adminRoutes');

const app = express();

// Connect to database
connectDB();

// Ensure upload folders exist
const uploadDir = path.join(__dirname, "uploads", "customers");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

app.use(cors());
app.use(express.json());

// ===================== REQUEST LOGGER =====================
app.use((req, res, next) => {
  console.log("======================================");
  console.log("Method :", req.method);
  console.log("URL    :", req.originalUrl);
  console.log("IP     :", req.ip);
  console.log("======================================");
  next();
});
// ==========================================================

// Serve public folder
app.use(express.static(path.join(__dirname, "public")));

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/employees", employeeRoutes);
app.use("/api/customers", customerRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/feedback", require("./routes/feedbackRoutes"));
app.use("/api/branches", branchRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/admins", adminRoutes);

// Uploads
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// Test Route
app.get("/", (req, res) => {
  res.send("Server Running...");
});

// Feedback Page
app.get("/feedback/:token", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "feedback.html"));
});

const PORT = process.env.PORT || 5000;

// Listen on all network interfaces
app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
  
  // Initialize notification cron after server starts
  setTimeout(() => {
    try {
      const notificationCron = require('./cron/notificationCron');
      if (typeof notificationCron.initNotificationCron === 'function') {
        notificationCron.initNotificationCron();
        console.log('✅ Notification cron jobs started');
      } else {
        console.log('⚠️ initNotificationCron is not a function, checking exports...');
        console.log('Available exports:', Object.keys(notificationCron));
      }
    } catch (error) {
      console.error('❌ Failed to initialize notification cron:', error.message);
    }
  }, 3000);
});