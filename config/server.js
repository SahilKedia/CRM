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
const adminRoutes = require("./routes/adminRoutes");

// WhatsApp Utility
const { sendPlainWhatsAppMessage } = require("./utils/whatsapp");

const app = express();

// ===================== DATABASE =====================
connectDB();

// ===================== UPLOAD FOLDERS =====================
const uploadDir = path.join(__dirname, "uploads", "customers");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// ===================== MIDDLEWARE =====================
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

// ===================== STATIC FILES =====================
app.use(express.static(path.join(__dirname, "public")));
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ===================== API ROUTES =====================
app.use("/api/auth", authRoutes);
app.use("/api/employees", employeeRoutes);
app.use("/api/customers", customerRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/feedback", require("./routes/feedbackRoutes"));
app.use("/api/branches", branchRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/admins", adminRoutes);

// ===================== TEST ROUTE =====================
app.get("/", (req, res) => {
  res.send("Server Running...");
});

// ===================== FEEDBACK PAGE =====================
app.get("/feedback/:token", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "feedback.html"));
});

// =======================================================
//                WHATSAPP WEBHOOK
// =======================================================

const WHATSAPP_VERIFY_TOKEN = "maliram_webhook_secret123";

// Meta Verification
app.get("/webhook", (req, res) => {
  const mode = req.query["hub.mode"];
  const token = req.query["hub.verify_token"];
  const challenge = req.query["hub.challenge"];

  if (mode === "subscribe" && token === WHATSAPP_VERIFY_TOKEN) {
    console.log("✅ Webhook verified successfully");
    return res.status(200).send(challenge);
  }

  console.log("❌ Webhook verification failed");
  return res.sendStatus(403);
});

// Incoming WhatsApp Events
app.post("/webhook", async (req, res) => {
  console.log("📩 Webhook event received:");
  console.log(JSON.stringify(req.body, null, 2));

  try {
    const entry = req.body.entry?.[0];
    const change = entry?.changes?.[0];
    const value = change?.value;

    // Ignore delivery/read status updates
    if (value?.statuses) {
      console.log("ℹ️ Status update received");
      return res.sendStatus(200);
    }

    const message = value?.messages?.[0];

    if (!message) {
      console.log("⚠️ No incoming message found.");
      return res.sendStatus(200);
    }

    console.log("📨 Incoming Message Type:", message.type);

    // Handle Interactive Button Reply
    if (message.type === "button") {
      const buttonText = message.button?.text;
      const customerPhone = message.from;

      console.log(`🔘 Button Clicked: ${buttonText}`);
      console.log(`📱 Customer: ${customerPhone}`);

      if (
        buttonText === "Great experience!" ||
        buttonText === "Could be better"
      ) {
        const communityMessage =
          "Thank you! ❤️\n\nStay connected with us for updates on new arrivals & exclusive offers.\n\nJoin our WhatsApp Channel:\nhttps://whatsapp.com/channel/0029Vb80rMoF6sn58DSye70g";

        await sendPlainWhatsAppMessage(customerPhone, communityMessage);

        console.log(`✅ Community link sent to ${customerPhone}`);
      }
    }

    // Handle Interactive Reply Buttons (new Meta format)
    else if (message.type === "interactive") {
      const customerPhone = message.from;

      const buttonTitle =
        message.interactive?.button_reply?.title ||
        message.interactive?.list_reply?.title;

      console.log(`🔘 Interactive Reply: ${buttonTitle}`);

      if (
        buttonTitle === "Great experience!" ||
        buttonTitle === "Could be better"
      ) {
        const communityMessage =
          "Thank you! 🙏\n\nStay connected with us for updates on new arrivals & exclusive offers.\n\nJoin our WhatsApp Channel:\nhttps://whatsapp.com/channel/0029Vb80rMoF6sn58DSye70g";

        await sendPlainWhatsAppMessage(customerPhone, communityMessage);

        console.log(`✅ Community link sent to ${customerPhone}`);
      }
    }

    // Handle normal text messages
    else if (message.type === "text") {
      console.log(
        `💬 Text from ${message.from}: ${message.text?.body || ""}`
      );
    } else {
      console.log(`ℹ️ Unhandled message type: ${message.type}`);
    }
  } catch (err) {
    console.error("❌ Error handling webhook:", err);
  }

  return res.sendStatus(200);
});

// =======================================================

const PORT = process.env.PORT || 5000;

// ===================== START SERVER =====================
app.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);

  // Initialize Notification Cron
  setTimeout(() => {
    try {
      const notificationCron = require("./cron/notificationCron");

      if (typeof notificationCron.initNotificationCron === "function") {
        notificationCron.initNotificationCron();
        console.log("✅ Notification cron jobs started");
      } else {
        console.log(
          "⚠️ initNotificationCron is not a function."
        );
        console.log(
          "Available exports:",
          Object.keys(notificationCron)
        );
      }
    } catch (error) {
      console.error(
        "❌ Failed to initialize notification cron:",
        error.message
      );
    }
  }, 3000);
});