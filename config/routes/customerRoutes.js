const express = require("express");
const router = express.Router();
const { protect, restrictTo } = require("../middleware/auth");
const upload = require("../middleware/upload");
const Notification = require('../models/Notification');
const Customer = require('../models/Customer');
const customerController = require('../controllers/customerController');

// Import controller functions
const {
  addCustomer,
  getCustomers,
  getCustomerById,
  updateCustomer,
  deleteCustomer,
  checkDuplicateCustomer,
  addVisit,
  updateVisit,
  getVisitByNumber,
   deleteVisit,
  // createSpecialDayNotifications,  // NOTIFICATION: commented
} = require("../controllers/customerController");

// ------------------------------------------------------------------
// 1. DEBUG: Check each imported function
// ------------------------------------------------------------------
console.log("✅ Customer Routes Initialized");
console.log("📋 addCustomer:", typeof addCustomer === "function" ? "✅" : "❌");
console.log("📋 getCustomers:", typeof getCustomers === "function" ? "✅" : "❌");
console.log("📋 getCustomerById:", typeof getCustomerById === "function" ? "✅" : "❌");
console.log("📋 updateCustomer:", typeof updateCustomer === "function" ? "✅" : "❌");
console.log("📋 deleteCustomer:", typeof deleteCustomer === "function" ? "✅" : "❌");
console.log("📋 checkDuplicateCustomer:", typeof checkDuplicateCustomer === "function" ? "✅" : "❌");
console.log("📋 addVisit:", typeof addVisit === "function" ? "✅" : "❌");
console.log("📋 updateVisit:", typeof updateVisit === "function" ? "✅" : "❌");
console.log("📋 getVisitByNumber:", typeof getVisitByNumber === "function" ? "✅" : "❌");
// console.log("📋 createSpecialDayNotifications:", typeof createSpecialDayNotifications === "function" ? "✅" : "❌");

// ------------------------------------------------------------------
// 2. Helper for branch scoping
// ------------------------------------------------------------------
function isBlockedByBranch(req, customer) {
  return (
    req.user &&
    req.user.role === "admin" &&
    req.user.branch &&
    customer.branch?.toString() !== req.user.branch?.toString()
  );
}

// ------------------------------------------------------------------
// 3. Routes – REGISTER ONLY IF HANDLER IS A FUNCTION
// ------------------------------------------------------------------

// Duplicate check
if (typeof checkDuplicateCustomer === "function") {
  router.get("/check-duplicate", protect, checkDuplicateCustomer);
} else {
  console.error("❌ checkDuplicateCustomer is not a function – route skipped");
}

// Create customer
if (typeof addCustomer === "function") {
  router.post(
    "/",
    protect,
    restrictTo("admin"),
   upload.fields([
      { name: "goldImages", maxCount: 100 },
      { name: "diamondImages", maxCount: 100 },
      { name: "polkiImages", maxCount: 100 },
      { name: "customerImage", maxCount: 1 },
    ]),
    upload.handleUploadErrors,
    addCustomer
  );
} else {
  console.error("❌ addCustomer is not a function – route skipped");
}

  // Delete a specific visit
router.delete("/:id/visits/:visitNumber", protect, restrictTo("admin"), async (req, res) => {
  try {
    const { id, visitNumber } = req.params;
    const customer = await Customer.findById(id);
    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }
    // Optional: branch check
    if (isBlockedByBranch(req, customer)) {
      return res.status(403).json({
        success: false,
        message: "You can only delete visits for customers in your branch",
      });
    }
    const visitIndex = customer.visits.findIndex(v => v.visitNumber === parseInt(visitNumber));
    if (visitIndex === -1) {
      return res.status(404).json({ success: false, message: `Visit #${visitNumber} not found` });
    }
    // Remove the visit
    customer.visits.splice(visitIndex, 1);
    await customer.save();
    res.json({
      success: true,
      message: `Visit #${visitNumber} deleted successfully`,
      data: customer
    });
  } catch (err) {
    console.error('❌ Error deleting visit:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});
// Add visit (POST to add a new visit to an existing customer)
if (typeof addVisit === "function") {
  router.post(
    "/:id/visits",
    protect,
    restrictTo("admin"),
    upload.fields([
      { name: "goldImages", maxCount: 100 },
      { name: "diamondImages", maxCount: 100 },
      { name: "polkiImages", maxCount: 100 },
    ]),
    upload.handleUploadErrors,
    addVisit
  );
} else {
  console.error("❌ addVisit is not a function – route skipped");
}

// Update visit (PUT to edit an existing visit)
if (typeof updateVisit === "function") {
  router.put(
    "/:id/visits/:visitNumber",
    protect,
    restrictTo("admin"),
    upload.fields([
      { name: "goldImages", maxCount: 10 },
      { name: "diamondImages", maxCount: 10 },
      { name: "polkiImages", maxCount: 10 },
    ]),
    upload.handleUploadErrors,
    updateVisit
  );
} else {
  console.error("❌ updateVisit is not a function – route skipped");
}

// Get specific visit by visit number
if (typeof getVisitByNumber === "function") {
  router.get("/:id/visits/:visitNumber", protect, getVisitByNumber);
} else {
  console.error("❌ getVisitByNumber is not a function – using fallback handler");
  router.get("/:id/visits/:visitNumber", protect, (req, res) => {
    res.status(501).json({
      success: false,
      message: "getVisitByNumber is not implemented in the controller"
    });
  });
}
router.get('/distinct/professions', protect, customerController.getDistinctProfessions);
router.get('/distinct/communities',  protect, customerController.getDistinctCommunities);
// Complete reminder for a specific visit
router.put("/:id/visits/:visitNumber/reminder/complete", protect, async (req, res) => {
  try {
    const { id, visitNumber } = req.params;
    const customer = await Customer.findById(id);
    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }
    if (isBlockedByBranch(req, customer)) {
      return res.status(403).json({
        success: false,
        message: "You can only manage reminders for customers in your branch",
      });
    }
    const visit = customer.visits.find(v => v.visitNumber === parseInt(visitNumber));
    if (!visit) {
      return res.status(404).json({ success: false, message: `Visit #${visitNumber} not found` });
    }
    if (!visit.reminder) {
      return res.status(404).json({ success: false, message: 'No reminder found for this visit' });
    }
    visit.reminder.status = 'completed';
    visit.reminder.completedAt = new Date();
    visit.reminder.date = null;
    visit.reminder.note = '';
    await customer.save();
    // NOTIFICATION: commented out notification deletion
    // await Notification.deleteMany({ customerId: customer._id, visitNumber: parseInt(visitNumber), type: 'reminder' });
    res.json({
      success: true,
      message: `Reminder for Visit #${visitNumber} completed and cleared`,
      data: customer
    });
  } catch (err) {
    console.error('❌ Error completing reminder:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get all pending reminders
router.get("/reminders/pending", protect, async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const filter = {
      'visits.reminder.status': 'pending',
      'visits.reminder.date': { $ne: null }
    };
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    } else if (req.query.branch) {
      filter.branch = req.query.branch;
    }
    const customers = await Customer.find(filter)
      .populate('branch', 'name city')
      .populate('assignedTo', 'name')
      .select('name phone email visits branch assignedTo');
    const pendingReminders = [];
    customers.forEach(customer => {
      customer.visits.forEach(visit => {
        if (visit.reminder && visit.reminder.status === 'pending' && visit.reminder.date) {
          const reminderDate = new Date(visit.reminder.date);
          reminderDate.setHours(0, 0, 0, 0);
          const daysUntil = Math.ceil((reminderDate - today) / (1000 * 60 * 60 * 24));
          pendingReminders.push({
            customerId: customer._id,
            customerName: customer.name,
            customerPhone: customer.phone,
            customerEmail: customer.email,
            branch: customer.branch,
            assignedTo: customer.assignedTo,
            visitNumber: visit.visitNumber,
            visitDate: visit.visitDate,
            purposeOfVisit: visit.purposeOfVisit,
            reminder: visit.reminder,
            daysUntil: daysUntil
          });
        }
      });
    });
    pendingReminders.sort((a, b) => new Date(a.reminder.date) - new Date(b.reminder.date));
    res.json({ success: true, count: pendingReminders.length, data: pendingReminders });
  } catch (err) {
    console.error('❌ Error fetching pending reminders:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Get reminder for a specific visit
router.get("/:id/visits/:visitNumber/reminder", protect, async (req, res) => {
  try {
    const { id, visitNumber } = req.params;
    const customer = await Customer.findById(id);
    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }
    if (isBlockedByBranch(req, customer)) {
      return res.status(403).json({
        success: false,
        message: "You don't have access to this customer",
      });
    }
    const visit = customer.visits.find(v => v.visitNumber === parseInt(visitNumber));
    if (!visit) {
      return res.status(404).json({ success: false, message: `Visit #${visitNumber} not found` });
    }
    res.json({
      success: true,
      data: {
        customer: { _id: customer._id, name: customer.name, phone: customer.phone },
        visit: {
          visitNumber: visit.visitNumber,
          visitDate: visit.visitDate,
          purposeOfVisit: visit.purposeOfVisit,
          reminder: visit.reminder || null
        }
      }
    });
  } catch (err) {
    console.error('❌ Error fetching reminder:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Update reminder for a specific visit
router.put("/:id/visits/:visitNumber/reminder", protect, restrictTo("admin"), async (req, res) => {
  try {
    const { id, visitNumber } = req.params;
    const { date, note, status } = req.body;
    const customer = await Customer.findById(id);
    if (!customer) {
      return res.status(404).json({ success: false, message: 'Customer not found' });
    }
    if (isBlockedByBranch(req, customer)) {
      return res.status(403).json({
        success: false,
        message: "You can only update reminders for customers in your branch",
      });
    }
    const visit = customer.visits.find(v => v.visitNumber === parseInt(visitNumber));
    if (!visit) {
      return res.status(404).json({ success: false, message: `Visit #${visitNumber} not found` });
    }
    if (!visit.reminder) visit.reminder = {};
    if (date !== undefined) visit.reminder.date = date ? new Date(date) : null;
    if (note !== undefined) visit.reminder.note = note;
    if (status !== undefined) {
      visit.reminder.status = status;
      if (status === 'completed') visit.reminder.completedAt = new Date();
    }
    await customer.save();
    res.json({
      success: true,
      message: `Reminder for Visit #${visitNumber} updated successfully`,
      data: {
        customer: { _id: customer._id, name: customer.name },
        visit: { visitNumber: visit.visitNumber, reminder: visit.reminder }
      }
    });
  } catch (err) {
    console.error('❌ Error updating reminder:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// NOTIFICATION: Special‑day notifications route commented out
// if (typeof createSpecialDayNotifications === "function") {
//   router.post("/notifications/special-days", protect, restrictTo("admin"), createSpecialDayNotifications);
// } else {
//   console.error("❌ createSpecialDayNotifications is not a function – route skipped");
// }

// GET all & by ID
if (typeof getCustomers === "function") {
  router.get("/", protect, getCustomers);
} else {
  console.error("❌ getCustomers is not a function – route skipped");
}
if (typeof getCustomerById === "function") {
  router.get("/:id", protect, getCustomerById);
} else {
  console.error("❌ getCustomerById is not a function – route skipped");
}

// PUT & DELETE
// if (typeof updateCustomer === "function") {
//   router.put("/:id", protect, restrictTo("admin"), updateCustomer);
// } else {
  if (typeof updateCustomer === "function") {
  router.put(
    "/:id",
    protect,
    restrictTo("admin"),
    upload.fields([{ name: "customerImage", maxCount: 1 }]),
    upload.handleUploadErrors,
    updateCustomer
  );
} else {
  console.error("❌ updateCustomer is not a function – route skipped");
}
if (typeof deleteCustomer === "function") {
  router.delete("/:id", protect, restrictTo("admin"), deleteCustomer);
} else {
  console.error("❌ deleteCustomer is not a function – route skipped");
}

module.exports = router;