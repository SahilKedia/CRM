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
  fulfillRequirement,
  getPendingRequirements,
  getDistinctProfessions,
  getDistinctCommunities,
  getCustomerReferralCircle,
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
console.log("📋 fulfillRequirement:", typeof fulfillRequirement === "function" ? "✅" : "❌");
console.log("📋 getPendingRequirements:", typeof getPendingRequirements === "function" ? "✅" : "❌");

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

// ==================== DISTINCT VALUES ====================
router.get('/distinct/professions', protect, getDistinctProfessions);
router.get('/distinct/communities', protect, getDistinctCommunities);

// ==================== DUPLICATE CHECK ====================
if (typeof checkDuplicateCustomer === "function") {
  router.get("/check-duplicate", protect, checkDuplicateCustomer);
} else {
  console.error("❌ checkDuplicateCustomer is not a function – route skipped");
}

// ==================== PENDING REQUIREMENTS ====================
// Get all pending requirements (must come before "/:id" routes)
if (typeof getPendingRequirements === "function") {
  router.get("/requirements/pending", protect, getPendingRequirements);
} else {
  console.error("❌ getPendingRequirements is not a function – route skipped");
}

// ==================== CREATE CUSTOMER ====================
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
      { name: "additionalInfoImage", maxCount: 1 } // ✅ ADDED
    ]),
    upload.handleUploadErrors,
    addCustomer
  );
} else {
  console.error("❌ addCustomer is not a function – route skipped");
}

// ==================== GET ALL CUSTOMERS ====================
if (typeof getCustomers === "function") {
  router.get("/", protect, getCustomers);
} else {
  console.error("❌ getCustomers is not a function – route skipped");
}

// ==================== GET CUSTOMER BY ID ====================
if (typeof getCustomerById === "function") {
  router.get("/:id", protect, getCustomerById);
} else {
  console.error("❌ getCustomerById is not a function – route skipped");
}

// ==================== GET REFERRAL CIRCLE ====================
if (typeof getCustomerReferralCircle === "function") {
  router.get("/:id/referral-circle", protect, getCustomerReferralCircle);
} else {
  console.error("❌ getCustomerReferralCircle is not a function – route skipped");
}

// ==================== UPDATE CUSTOMER ====================
if (typeof updateCustomer === "function") {
  router.put(
    "/:id",
    protect,
    restrictTo("admin"),
    upload.fields([
      { name: "customerImage", maxCount: 1 },
      { name: "additionalInfoImage", maxCount: 1 } // ✅ ADDED
    ]),
    upload.handleUploadErrors,
    updateCustomer
  );
} else {
  console.error("❌ updateCustomer is not a function – route skipped");
}

// ==================== DELETE CUSTOMER ====================
if (typeof deleteCustomer === "function") {
  router.delete("/:id", protect, restrictTo("admin"), deleteCustomer);
} else {
  console.error("❌ deleteCustomer is not a function – route skipped");
}

// ==================== ADD VISIT TO CUSTOMER ====================
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

// ==================== UPDATE VISIT ====================
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

// ==================== GET SPECIFIC VISIT ====================
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

// ==================== DELETE SPECIFIC VISIT ====================
if (typeof deleteVisit === "function") {
  router.delete("/:id/visits/:visitNumber", protect, restrictTo("admin"), deleteVisit);
} else {
  console.error("❌ deleteVisit is not a function – using fallback handler");
  router.delete("/:id/visits/:visitNumber", protect, restrictTo("admin"), async (req, res) => {
    try {
      const { id, visitNumber } = req.params;
      const customer = await Customer.findById(id);
      if (!customer) {
        return res.status(404).json({ success: false, message: 'Customer not found' });
      }
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
      customer.visits.splice(visitIndex, 1);
      customer.numberOfVisit = customer.visits.length;
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
}

// ==================== FULFILL REQUIREMENT ====================
if (typeof fulfillRequirement === "function") {
  router.patch(
    "/:id/visits/:visitNumber/fulfill-requirement",
    protect,
    restrictTo("admin"),
    fulfillRequirement
  );
} else {
  console.error("❌ fulfillRequirement is not a function – route skipped");
}

// ==================== REMINDER ROUTES ====================

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

module.exports = router;