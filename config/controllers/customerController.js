// backend/controllers/customerController.js
const Customer = require("../models/Customer");
// const Employee = require("../models/Employee");   // NOTIFICATION: commented
// const Notification = require("../models/Notification"); // NOTIFICATION: commented
const { createAndSendFeedbackRequest } = require("./feedbackController");

// ==================== VIP / CUSTOMER CLASS LOGIC ====================
// function computeCustomerClass(customerDoc) {
//   if (customerDoc.manualClassOverride) return customerDoc.manualClassOverride;

//   const visits = customerDoc.visits || [];
//   const numberOfVisit = customerDoc.numberOfVisit || visits.length || 1;

//   // total distinct jewelry items shown/bought across ALL visits
//   const totalItems = visits.reduce((sum, v) => {
//     let count = 0;
//     if (v.gold) count++;
//     if (v.diamond) count++;
//     if (v.polki) count++;
//     return sum + count;
//   }, 0);

//   const soldVisits = visits.filter((v) => v.conclusion === "Sold").length;

//   const vipProfessions = ["Business Man", "Doctor"];
//   const isVipProfession = vipProfessions.includes(customerDoc.profession);

//   if (soldVisits >= 1 && totalItems >= 5) return "Big Spender";
//   if (numberOfVisit >= 5) return "Loyal";
//   if (isVipProfession && numberOfVisit >= 2) return "VIP";
//   return "Regular";
// }
function computeCustomerClass(customerDoc) {
  if (customerDoc.manualClassOverride) return customerDoc.manualClassOverride;

  const visits = customerDoc.visits || [];
  const numberOfVisit = customerDoc.numberOfVisit || visits.length || 1;

  // total distinct jewelry items shown/bought across ALL visits
  const totalItems = visits.reduce((sum, v) => {
    let count = 0;
    if (v.gold) count++;
    if (v.diamond) count++;
    if (v.polki) count++;
    return sum + count;
  }, 0);

  const soldVisits = visits.filter((v) => v.conclusion === "Sold").length;

  // ✅ VIP: any profession (non‑empty) + at least 2 visits
  const hasProfession = !!(customerDoc.profession && customerDoc.profession.trim());

  if (soldVisits >= 1 && totalItems >= 5) return "Big Spender";
  if (numberOfVisit >= 5) return "Loyal";
  if (hasProfession && numberOfVisit >= 2) return "VIP";
  return "Regular";
}

// ==================== CONTROLLER FUNCTIONS ====================

// Add Customer
exports.addCustomer = async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      address,
      branch,
      visitDate,
      purposeOfVisit,
      numberOfVisit,
      gold,
      diamond,
      polki,
      requirement,
      // approval,
      whoAttend,
      helper,
      reminderDate,
      reminderMessage,
      conclusion,
      birthday,
      anniversary,
      profession,
      community,
      referenceNote,
      referredBy,
      assignedTo,
    } = req.body;

    // Validate required fields
    if (!name || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: "Customer name is required",
      });
    }

    if (!assignedTo || !assignedTo.trim()) {
      return res.status(400).json({
        success: false,
        message: "Assigned employee is required",
      });
    }

    const finalBranch = req.user?.branch || branch;
    if (!finalBranch) {
      return res.status(400).json({
        success: false,
        message: "Branch is required",
      });
    }

    let finalReferredBy = undefined;
    if (referredBy && referredBy.trim()) {
      const referrer = await Customer.findById(referredBy.trim());
      if (!referrer) {
        return res.status(400).json({
          success: false,
          message: "Selected reference customer not found",
        });
      }
      finalReferredBy = referrer._id;
    }

    // Handle image uploads
// Handle image uploads — store relative paths only (no host/IP baked in)
// const goldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
// const diamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
// const polkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);
     // Handle image uploads — store relative paths only (no host/IP baked in)

const goldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
const diamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
const polkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

// Handle customer profile photo (single image, optional)
const customerImageFile = req.files?.customerImage?.[0];
const customerImage = customerImageFile
  ? `uploads/customers/${customerImageFile.filename}`
  : undefined;
    // Handle reminder
    let finalReminder = undefined;
    if (reminderDate) {
      finalReminder = {
        date: new Date(reminderDate),
        note: reminderMessage?.trim() || "",
        status: "pending",
        completedAt: null,
      };
    } else if (reminderMessage) {
      finalReminder = {
        date: new Date(),
        note: reminderMessage.trim(),
        status: "pending",
        completedAt: null,
      };
    }

    // Build the FIRST visit record
    const firstVisit = {
      visitNumber: 1,
      visitDate: visitDate ? new Date(visitDate) : new Date(),
      purposeOfVisit: purposeOfVisit?.trim() || undefined,
      gold: gold || undefined,
      diamond: diamond || undefined,
      polki: polki || undefined,
      goldImages: goldImages.length > 0 ? goldImages : undefined,
      diamondImages: diamondImages.length > 0 ? diamondImages : undefined,
      polkiImages: polkiImages.length > 0 ? polkiImages : undefined,
      requirement: requirement?.trim() || undefined,
      // approval: approval || "pending",
      conclusion: conclusion || "Pending",
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
    };

    // Create customer with visits array properly initialized
    const customer = new Customer({
      name: name.trim(),
      email: email?.trim() || undefined,
      phone: phone?.trim() || undefined,
      address: address?.trim() || undefined,
      customerImage: customerImage,
      branch: finalBranch,
      visits: [firstVisit], // ✅ Initialize visits array with first visit
      visitDate: firstVisit.visitDate,
      purposeOfVisit: firstVisit.purposeOfVisit,
      numberOfVisit: 1, // ✅ Start with 1
      gold: gold || undefined,
      diamond: diamond || undefined,
      polki: polki || undefined,
      goldImages: goldImages.length > 0 ? goldImages : undefined,
      diamondImages: diamondImages.length > 0 ? diamondImages : undefined,
      polkiImages: polkiImages.length > 0 ? polkiImages : undefined,
      requirement: requirement?.trim() || undefined,
      // approval: approval || "pending",
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
      reminder: finalReminder,
      conclusion: conclusion || "Pending",
      birthday: birthday?.trim() || undefined,
      anniversary: anniversary?.trim() || undefined,
      profession: profession?.trim() || undefined,
      community: community?.trim() || undefined,
      referenceNote: referenceNote?.trim() || undefined,
      referredBy: finalReferredBy,
      assignedTo: assignedTo.trim(),
    });

    // Compute customer class
    customer.customerClass = computeCustomerClass(customer);
    await customer.save();

    // NOTIFICATION: commented out birthday/anniversary notification creation
    // await createBirthdayAnniversaryNotifications(customer, finalBranch);

    // NOTIFICATION: commented out feedback request
    if (createAndSendFeedbackRequest) {
      createAndSendFeedbackRequest(customer);
    }

    res.status(201).json({
      success: true,
      message: "Customer Added Successfully",
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error adding customer:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to add customer",
    });
  }
};

// Add a NEW visit to an EXISTING customer
exports.addVisit = async (req, res) => {
  try {
    const { id } = req.params;
    const customer = await Customer.findById(id);

    if (!customer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    if (req.user && req.user.role === "admin" && req.user.branch) {
      if (customer.branch?.toString() !== req.user.branch?.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only add visits for customers in your branch",
        });
      }
    }

    const {
      purposeOfVisit,
      gold,
      diamond,
      polki,
      requirement,
      // approval,
      conclusion,
      whoAttend,
      helper,
      visitDate,
    } = req.body;

const goldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
const diamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
const polkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    // ✅ Ensure visits array exists
    if (!customer.visits) {
      customer.visits = [];
    }

    // ✅ Optional: check for duplicate visit (prevent double submission)
    const existingVisit = customer.visits.find(v => 
      v.visitDate && visitDate && 
      new Date(v.visitDate).toDateString() === new Date(visitDate).toDateString() &&
      v.purposeOfVisit === purposeOfVisit?.trim()
    );

    if (existingVisit) {
      return res.status(400).json({
        success: false,
        message: "A visit with same date and purpose already exists",
      });
    }

    const newVisit = {
      visitNumber: customer.visits.length + 1, // ✅ Increment based on actual array length
      visitDate: visitDate ? new Date(visitDate) : new Date(),
      purposeOfVisit: purposeOfVisit?.trim() || undefined,
      gold: gold || undefined,
      diamond: diamond || undefined,
      polki: polki || undefined,
      goldImages: goldImages.length ? goldImages : undefined,
      diamondImages: diamondImages.length ? diamondImages : undefined,
      polkiImages: polkiImages.length ? polkiImages : undefined,
      requirement: requirement?.trim() || undefined,
      // approval: approval || "pending",
      conclusion: conclusion || "Pending",
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
    };

    // ✅ PUSH the new visit to the visits array
    customer.visits.push(newVisit);
    
    // ✅ Update numberOfVisit based on actual array length
    customer.numberOfVisit = customer.visits.length;

    // ✅ Mirror the LATEST visit at top level for backward compatibility
    const latestVisit = customer.visits[customer.visits.length - 1];
    customer.visitDate = latestVisit.visitDate;
    customer.purposeOfVisit = latestVisit.purposeOfVisit;
    customer.gold = latestVisit.gold;
    customer.diamond = latestVisit.diamond;
    customer.polki = latestVisit.polki;
    customer.goldImages = latestVisit.goldImages;
    customer.diamondImages = latestVisit.diamondImages;
    customer.polkiImages = latestVisit.polkiImages;
    customer.requirement = latestVisit.requirement;
    // customer.approval = latestVisit.approval;
    customer.conclusion = latestVisit.conclusion;
    customer.whoAttend = latestVisit.whoAttend;
    customer.helper = latestVisit.helper;

    // Recompute customer class
    customer.customerClass = computeCustomerClass(customer);

    await customer.save();

    res.status(201).json({
      success: true,
      message: `Visit #${newVisit.visitNumber} added successfully`,
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error adding visit:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to add visit",
    });
  }
};
// Update an EXISTING visit (e.g. status change from "Just See" -> "Sold")
exports.updateVisit = async (req, res) => {
  try {
    const { id, visitNumber } = req.params;
    const customer = await Customer.findById(id);

    if (!customer) {
      return res.status(404).json({ success: false, message: "Customer not found" });
    }

    if (req.user && req.user.role === "admin" && req.user.branch) {
      if (customer.branch?.toString() !== req.user.branch?.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only edit visits for customers in your branch",
        });
      }
    }

    const visitIndex = customer.visits.findIndex(
      (v) => v.visitNumber === parseInt(visitNumber)
    );
    if (visitIndex === -1) {
      return res.status(404).json({
        success: false,
        message: `Visit #${visitNumber} not found`,
      });
    }

    const visit = customer.visits[visitIndex];

    const {
      purposeOfVisit,
      gold,
      diamond,
      polki,
      requirement,
      // approval,
      conclusion,
      whoAttend,
      helper,
      visitDate,
      removeGoldImages,     // JSON stringified array of urls to delete
      removeDiamondImages,
      removePolkiImages,
    } = req.body;

const newGoldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
const newDiamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
const newPolkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    let goldImages = visit.goldImages || [];
    let diamondImages = visit.diamondImages || [];
    let polkiImages = visit.polkiImages || [];
// Match by filename only, so it works whether the client sends
    // full URLs (old cached data) or relative paths (new format)
    const getFilename = (p) => p.split("/").pop().split("?")[0];

    if (removeGoldImages) {
      const toRemove = JSON.parse(removeGoldImages).map(getFilename);
      goldImages = goldImages.filter((url) => !toRemove.includes(getFilename(url)));
    }
    if (removeDiamondImages) {
      const toRemove = JSON.parse(removeDiamondImages).map(getFilename);
      diamondImages = diamondImages.filter((url) => !toRemove.includes(getFilename(url)));
    }
    if (removePolkiImages) {
      const toRemove = JSON.parse(removePolkiImages).map(getFilename);
      polkiImages = polkiImages.filter((url) => !toRemove.includes(getFilename(url)));
    }

    goldImages = [...goldImages, ...newGoldImages];
    diamondImages = [...diamondImages, ...newDiamondImages];
    polkiImages = [...polkiImages, ...newPolkiImages];

    if (purposeOfVisit !== undefined) visit.purposeOfVisit = purposeOfVisit.trim();
    if (gold !== undefined) visit.gold = gold;
    if (diamond !== undefined) visit.diamond = diamond;
    if (polki !== undefined) visit.polki = polki;
    if (requirement !== undefined) visit.requirement = requirement.trim();
    // if (approval !== undefined) visit.approval = approval;
    if (conclusion !== undefined) visit.conclusion = conclusion;
    if (whoAttend !== undefined) visit.whoAttend = whoAttend.trim();
    if (helper !== undefined) visit.helper = helper.trim();
    if (visitDate) visit.visitDate = new Date(visitDate);

    visit.goldImages = goldImages.length ? goldImages : undefined;
    visit.diamondImages = diamondImages.length ? diamondImages : undefined;
    visit.polkiImages = polkiImages.length ? polkiImages : undefined;

    customer.visits[visitIndex] = visit;
    customer.markModified("visits");

    // Keep top-level fields in sync ONLY if this is the latest visit
    if (visitIndex === customer.visits.length - 1) {
      customer.visitDate = visit.visitDate;
      customer.purposeOfVisit = visit.purposeOfVisit;
      customer.gold = visit.gold;
      customer.diamond = visit.diamond;
      customer.polki = visit.polki;
      customer.goldImages = visit.goldImages;
      customer.diamondImages = visit.diamondImages;
      customer.polkiImages = visit.polkiImages;
      customer.requirement = visit.requirement;
      // customer.approval = visit.approval;
      customer.conclusion = visit.conclusion;
      customer.whoAttend = visit.whoAttend;
      customer.helper = visit.helper;
    }

    customer.customerClass = computeCustomerClass(customer);
    await customer.save();

    res.json({
      success: true,
      message: `Visit #${visitNumber} updated successfully`,
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error updating visit:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to update visit",
    });
  }
};
// Check duplicate customer
exports.checkDuplicateCustomer = async (req, res) => {
  try {
    const { phone, email, excludeId } = req.query;

    if (!phone && !email) {
      return res.json({ success: true, duplicate: false });
    }

    const orConditions = [];
    if (phone && phone.trim()) {
      orConditions.push({ phone: phone.trim() });
    }
    if (email && email.trim()) {
      orConditions.push({ email: email.trim().toLowerCase() });
    }

    const filter = { $or: orConditions };

    if (excludeId) {
      filter._id = { $ne: excludeId };
    }

    const existing = await Customer.findOne(filter)
      .populate("branch", "name city")
      .sort({ createdAt: -1 });

    if (!existing) {
      return res.json({ success: true, duplicate: false });
    }

    res.json({
      success: true,
      duplicate: true,
      data: {
        name: existing.name,
        branch: existing.branch,
        visitDate: existing.visitDate,
        phone: existing.phone,
        email: existing.email,
      },
    });
  } catch (err) {
    console.error("❌ Error checking duplicate customer:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to check duplicate customer",
    });
  }
};

// Get All Customers
exports.getCustomers = async (req, res) => {
  try {
    const filter = {};

    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    } else if (req.query.branch) {
      filter.branch = req.query.branch;
    }

    const customers = await Customer.find(filter)
      .populate("referredBy", "name phone")
      .populate("assignedTo", "name")
      .populate("branch", "name city")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: customers,
    });
  } catch (err) {
    console.error("❌ Error fetching customers:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch customers",
    });
  }
};

// Get Customer By ID
exports.getCustomerById = async (req, res) => {
  try {
    const { id } = req.params;

    const customer = await Customer.findById(id)
      .populate("referredBy", "name phone")
      .populate("assignedTo", "name")
      .populate("branch", "name city");

    if (!customer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    if (req.user && req.user.role === "admin" && req.user.branch) {
      const customerBranchId = customer.branch?._id?.toString() || customer.branch?.toString();
      if (customerBranchId !== req.user.branch.toString()) {
        return res.status(403).json({
          success: false,
          message: "You don't have access to this customer",
        });
      }
    }

    res.json({
      success: true,
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error fetching customer:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch customer",
    });
  }
};

// Get the full referral chain for a customer
exports.getCustomerReferralCircle = async (req, res) => {
  try {
    const { id } = req.params;

    const customer = await Customer.findById(id)
      .populate("referredBy", "name phone")
      .populate("assignedTo", "name");

    if (!customer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    const referredCustomers = await Customer.find({ referredBy: id })
      .select("name phone visitDate")
      .populate("assignedTo", "name");

    res.json({
      success: true,
      data: {
        customer,
        referredBy: customer.referredBy || null,
        referred: referredCustomers,
      },
    });
  } catch (err) {
    console.error("❌ Error fetching referral circle:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch referral circle",
    });
  }
};
   // ==================== DISTINCT VALUES ====================

// Get distinct professions (non-empty, sorted alphabetically)
exports.getDistinctProfessions = async (req, res) => {
  try {
    const filter = {};
    // Optional: restrict to current user's branch if needed
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    }
    // Only consider customers that have a non-empty profession
    filter.profession = { $ne: null, $ne: "" };

    const professions = await Customer.distinct("profession", filter);
    // Sort alphabetically and remove any empty strings just in case
    const sorted = professions
      .filter(p => p && p.trim().length > 0)
      .sort((a, b) => a.localeCompare(b));

    res.json({
      success: true,
      data: sorted,
    });
  } catch (err) {
    console.error("❌ Error fetching distinct professions:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch professions",
    });
  }
};

// Get distinct communities (non-empty, sorted alphabetically)
exports.getDistinctCommunities = async (req, res) => {
  try {
    const filter = {};
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    }
    filter.community = { $ne: null, $ne: "" };

    const communities = await Customer.distinct("community", filter);
    const sorted = communities
      .filter(c => c && c.trim().length > 0)
      .sort((a, b) => a.localeCompare(b));

    res.json({
      success: true,
      data: sorted,
    });
  } catch (err) {
    console.error("❌ Error fetching distinct communities:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch communities",
    });
  }
};
// Update Customer
exports.updateCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Handle new customer profile photo, if uploaded
    const newCustomerImageFile = req.files?.customerImage?.[0];
    if (newCustomerImageFile) {
      updateData.customerImage = `uploads/customers/${newCustomerImageFile.filename}`;
    }
    // Handle reminder update
    const hasReminderDate = updateData.reminderDate !== undefined;
    const hasReminderMessage = updateData.reminderMessage !== undefined;
    const hasReminderStatus = updateData.reminderStatus !== undefined;
    const hasClearReminder = updateData.clearReminder === true;

    if (hasClearReminder) {
      updateData.reminder = undefined;
      delete updateData.reminderDate;
      delete updateData.reminderMessage;
      delete updateData.reminderStatus;
      delete updateData.clearReminder;
    } else if (hasReminderDate || hasReminderMessage || hasReminderStatus) {
      const existingCustomer = await Customer.findById(id);

      let reminderObj = existingCustomer?.reminder || {
        date: null,
        status: "pending",
        completedAt: null,
        note: "",
      };

      if (hasReminderDate) {
        if (updateData.reminderDate && updateData.reminderDate.trim() !== "") {
          reminderObj.date = new Date(updateData.reminderDate);
        } else {
          reminderObj.date = null;
        }
      }

      if (hasReminderMessage) {
        reminderObj.note = updateData.reminderMessage?.trim() || "";
      }

      if (hasReminderStatus) {
        reminderObj.status = updateData.reminderStatus;
      }

      if ((hasReminderDate || hasReminderMessage) && !hasReminderStatus) {
        reminderObj.status = "pending";
      }

      if (reminderObj.date && reminderObj.status === "completed") {
        reminderObj.completedAt = new Date();
      } else if (reminderObj.status !== "completed") {
        reminderObj.completedAt = null;
      }

      if (reminderObj.date || reminderObj.note) {
        updateData.reminder = reminderObj;
      } else {
        updateData.reminder = undefined;
      }

      delete updateData.reminderDate;
      delete updateData.reminderMessage;
      delete updateData.reminderStatus;
      delete updateData.clearReminder;
    }

    // Trim optional fields
    if (updateData.birthday !== undefined) {
      updateData.birthday = updateData.birthday?.trim() || undefined;
    }
    if (updateData.anniversary !== undefined) {
      updateData.anniversary = updateData.anniversary?.trim() || undefined;
    }
    if (updateData.profession !== undefined) {
      updateData.profession = updateData.profession?.trim() || undefined;
    }
    if (updateData.community !== undefined) {
      updateData.community = updateData.community?.trim() || undefined;
    }

    // Find customer first
    const existingCustomer = await Customer.findById(id);
    if (!existingCustomer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    if (req.user && req.user.role === "admin" && req.user.branch) {
      if (existingCustomer.branch.toString() !== req.user.branch.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only update customers in your branch",
        });
      }
      delete updateData.branch;
    }

    // ✅ IMPORTANT: Don't allow direct modification of visits array through update
    // Only addVisit should modify visits
    delete updateData.visits;
    delete updateData.numberOfVisit; // This should be managed by the visit system

    console.log("📝 Updating customer with data:", JSON.stringify(updateData, null, 2));

    const customer = await Customer.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true,
      context: "query",
    })
      .populate("referredBy", "name phone")
      .populate("assignedTo", "name")
      .populate("branch", "name city");

    // Recompute class in case profession changed
    if (customer) {
      customer.customerClass = computeCustomerClass(customer);
      await customer.save();
      
      // NOTIFICATION: commented out birthday/anniversary notification creation
      // await createBirthdayAnniversaryNotifications(customer, existingCustomer.branch);
    }

    res.json({
      success: true,
      message: "Customer Updated Successfully",
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error updating customer:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to update customer",
    });
  }
};

// Delete Customer
exports.deleteCustomer = async (req, res) => {
  try {
    const { id } = req.params;

    const existingCustomer = await Customer.findById(id);
    if (!existingCustomer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    if (req.user && req.user.role === "admin" && req.user.branch) {
      if (existingCustomer.branch.toString() !== req.user.branch.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only delete customers in your branch",
        });
      }
    }

    // NOTIFICATION: commented out deletion of related notifications
    // await Notification.deleteMany({ customerId: id });
    
    // Delete customer
    await Customer.findByIdAndDelete(id);

    res.json({
      success: true,
      message: "Customer Deleted Successfully",
    });
  } catch (err) {
    console.error("❌ Error deleting customer:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to delete customer",
    });
  }
};

// Get a specific visit by visit number
exports.getVisitByNumber = async (req, res) => {
  try {
    const { id, visitNumber } = req.params;

    const customer = await Customer.findById(id)
      .populate("referredBy", "name phone")
      .populate("assignedTo", "name")
      .populate("branch", "name city");

    if (!customer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    // Branch scope check
    if (req.user && req.user.role === "admin" && req.user.branch) {
      if (customer.branch?.toString() !== req.user.branch?.toString()) {
        return res.status(403).json({
          success: false,
          message: "You don't have access to this customer",
        });
      }
    }

    const visit = customer.visits.find(v => v.visitNumber === parseInt(visitNumber));

    if (!visit) {
      return res.status(404).json({
        success: false,
        message: `Visit #${visitNumber} not found`,
      });
    }

    res.json({
      success: true,
      data: {
        customer: {
          _id: customer._id,
          name: customer.name,
          phone: customer.phone,
          email: customer.email,
        },
        visit,
      },
    });
  } catch (err) {
    console.error("❌ Error fetching visit by number:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch visit",
    });
  }
};
  // Delete a specific visit
exports.deleteVisit = async (req, res) => {
  try {
    const { id, visitNumber } = req.params;
    const customer = await Customer.findById(id);

    if (!customer) {
      return res.status(404).json({ success: false, message: "Customer not found" });
    }

    // Branch access control
    if (req.user && req.user.role === "admin" && req.user.branch) {
      if (customer.branch?.toString() !== req.user.branch?.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only delete visits for customers in your branch",
        });
      }
    }

    const visitIndex = customer.visits.findIndex(v => v.visitNumber === parseInt(visitNumber));
    if (visitIndex === -1) {
      return res.status(404).json({ success: false, message: `Visit #${visitNumber} not found` });
    }

    // Optionally, you can delete the associated image files from disk here
    // (skipping for brevity)

    // Remove the visit from the array
    customer.visits.splice(visitIndex, 1);

    // Update numberOfVisit based on new length
    customer.numberOfVisit = customer.visits.length;

    // Update top-level fields to the latest visit (if any)
    if (customer.visits.length > 0) {
      const latestVisit = customer.visits[customer.visits.length - 1];
      customer.visitDate = latestVisit.visitDate;
      customer.purposeOfVisit = latestVisit.purposeOfVisit;
      customer.gold = latestVisit.gold;
      customer.diamond = latestVisit.diamond;
      customer.polki = latestVisit.polki;
      customer.goldImages = latestVisit.goldImages;
      customer.diamondImages = latestVisit.diamondImages;
      customer.polkiImages = latestVisit.polkiImages;
      customer.requirement = latestVisit.requirement;
      customer.conclusion = latestVisit.conclusion;
      customer.whoAttend = latestVisit.whoAttend;
      customer.helper = latestVisit.helper;
    } else {
      // No visits left – clear top‑level fields
      customer.visitDate = undefined;
      customer.purposeOfVisit = undefined;
      customer.gold = undefined;
      customer.diamond = undefined;
      customer.polki = undefined;
      customer.goldImages = undefined;
      customer.diamondImages = undefined;
      customer.polkiImages = undefined;
      customer.requirement = undefined;
      customer.conclusion = undefined;
      customer.whoAttend = undefined;
      customer.helper = undefined;
    }

    // Recompute customer class
    customer.customerClass = computeCustomerClass(customer);

    await customer.save();

    res.json({
      success: true,
      message: `Visit #${visitNumber} deleted successfully`,
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error deleting visit:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to delete visit",
    });
  }
};


module.exports = {
  addCustomer: exports.addCustomer,
  addVisit: exports.addVisit,
  updateVisit: exports.updateVisit,
  checkDuplicateCustomer: exports.checkDuplicateCustomer,
  getCustomers: exports.getCustomers,
  getCustomerById: exports.getCustomerById,
  getCustomerReferralCircle: exports.getCustomerReferralCircle,
  updateCustomer: exports.updateCustomer,
  deleteCustomer: exports.deleteCustomer,
  getVisitByNumber: exports.getVisitByNumber,
  getDistinctProfessions: exports.getDistinctProfessions,
  getDistinctCommunities: exports.getDistinctCommunities,
   deleteVisit: exports.deleteVisit, 
};