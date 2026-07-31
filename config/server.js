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

// Feedback flow dependencies
const Feedback = require("./models/Feedback");
const Customer = require("./models/Customer");
const { sendFeedbackNotificationEmail } = require("./utils/mailer");

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

// Normalize incoming WhatsApp "from" number (e.g. "919999999999")
// to match how phone is stored on Customer (assumed 10-digit).
function normalizePhone(rawPhone) {
  let phone = String(rawPhone).replace(/\D/g, "");
  if (phone.length === 12 && phone.startsWith("91")) {
    phone = phone.slice(2);
  }
  return phone;
}

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

    const rawPhone = message.from;
    const normalizedPhone = normalizePhone(rawPhone);

    // ===================== BUTTON CLICKS =====================
    // Covers both the legacy "button" format and the newer "interactive" format
    if (message.type === "button" || message.type === "interactive") {
      const buttonTitle =
        message.button?.text ||
        message.interactive?.button_reply?.title ||
        message.interactive?.list_reply?.title;

      console.log(`🔘 Button Clicked: ${buttonTitle}`);
      console.log(`📱 Customer: ${rawPhone}`);

      if (buttonTitle === "Great experience!") {
        const communityMessage =
          "Thank you! ❤️\n\nStay connected with us for updates on new arrivals & exclusive offers.\n\nJoin our WhatsApp Channel:\nhttps://whatsapp.com/channel/0029Vb80rMoF6sn58DSye70g";

        await sendPlainWhatsAppMessage(rawPhone, communityMessage);

        console.log(`✅ Community link sent to ${rawPhone}`);
      }

      else if (buttonTitle === "Could be better") {
        // Ask the customer for their suggestion
        const askMessage =
          "We're sorry your experience wasn't perfect. 🙏\nPlease reply with your suggestion, and we'll work on improving.";

        await sendPlainWhatsAppMessage(rawPhone, askMessage);

        // Look up the customer record (optional — flow still works if not found)
        const customer = await Customer.findOne({ phone: normalizedPhone });

        // Mark this phone as "awaiting a suggestion reply"
        await Feedback.findOneAndUpdate(
          { customerPhone: normalizedPhone, source: "whatsapp" },
          {
            customer: customer?._id,
            customerName: customer?.name,
            customerPhone: normalizedPhone,
            branch: customer?.branch,
            status: "awaiting_reply",
            comments: undefined,
          },
          { upsert: true, new: true, setDefaultsOnInsert: true }
        );

        console.log(`⏳ Awaiting suggestion text from ${rawPhone}`);
      }
    }

    // ===================== TEXT REPLIES =====================
    else if (message.type === "text") {
      const text = message.text?.body?.trim() || "";
      console.log(`💬 Text from ${rawPhone}: ${text}`);

      // Is this phone currently awaiting a suggestion reply?
      const pendingFeedback = await Feedback.findOne({
        customerPhone: normalizedPhone,
        source: "whatsapp",
        status: "awaiting_reply",
      }).sort({ updatedAt: -1 });

      if (pendingFeedback && text) {
        pendingFeedback.comments = text;
        pendingFeedback.status = "submitted";
        pendingFeedback.submittedAt = new Date();
        await pendingFeedback.save();

        // Email Sahil with the customer's suggestion
        await sendFeedbackNotificationEmail({
          customerName: pendingFeedback.customerName,
          customerPhone: pendingFeedback.customerPhone,
          branch: pendingFeedback.branch,
          comment: text,
        });

        // Thank the customer
        await sendPlainWhatsAppMessage(
          rawPhone,
          "Thank you for your valuable feedback. We will work on improving your experience. 🙏"
        );

        console.log(`✅ Feedback saved + emailed for ${rawPhone}`);
      } else {
        console.log(
          "ℹ️ Text received but no pending feedback request for this number."
        );
      }
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