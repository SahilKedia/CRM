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

const app = express();

connectDB();

const uploadDir = path.join(__dirname, "uploads", "customers");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

app.use(cors());
app.use(express.json());

// 👇 ADD THIS
app.use((req, res, next) => {
  console.log("--------------------------------");
  console.log(`${req.method} ${req.originalUrl}`);
  console.log("IP:", req.ip);
  console.log("--------------------------------");
  next();
});

app.use(express.static(path.join(__dirname, "public")));

app.use("/api/auth", authRoutes);
app.use("/api/employees", employeeRoutes);
app.use("/api/customers", customerRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/feedback", require("./routes/feedbackRoutes"));
app.use("/api/branches", branchRoutes);

app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.get("/", (req, res) => {
  res.send("Server Running...");
});

app.get("/feedback/:token", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "feedback.html"));
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});