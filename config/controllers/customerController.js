// backend/controllers/customerController.js
const Customer = require("../models/Customer");
// const Employee = require("../models/Employee");   // NOTIFICATION: commented
// const Notification = require("../models/Notification"); // NOTIFICATION: commented
const { createAndSendFeedbackRequest } = require("./feedbackController");

// ==================== VIP / CUSTOMER CLASS LOGIC ====================
function computeCustomerClass(customerDoc) {
  if (customerDoc.manualClassOverride) return customerDoc.manualClassOverride;

  const visits = customerDoc.visits || [];
  const numberOfVisit = customerDoc.numberOfVisit || visits.length || 1;

  const totalItems = visits.reduce((sum, v) => {
    let count = 0;
    if (v.gold) count++;
    if (v.diamond) count++;
    if (v.polki) count++;
    return sum + count;
  }, 0);

  const soldVisits = visits.filter((v) => v.conclusion === "sold").length;

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
      additionalInfo, // ✅ ADDED
    } = req.body;

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

    // Handle image uploads — store relative paths only (no host/IP baked in)
    const goldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
    const diamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
    const polkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    // Handle customer profile photo (single image, optional)
    const customerImageFile = req.files?.customerImage?.[0];
    const customerImage = customerImageFile
      ? `uploads/customers/${customerImageFile.filename}`
      : undefined;

    // ✅ Handle additional info image (single image, optional)
    const additionalInfoImageFile = req.files?.additionalInfoImage?.[0];
    const additionalInfoImage = additionalInfoImageFile
      ? `uploads/customers/${additionalInfoImageFile.filename}`
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

    const trimmedRequirement = requirement?.trim() || undefined;

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
      requirement: trimmedRequirement,
      requirementStatus: trimmedRequirement ? "pending" : "none",
      conclusion: conclusion || "pending",
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
      additionalInfo: additionalInfo?.trim() || undefined, // ✅ ADDED
      additionalInfoImage: additionalInfoImage, // ✅ ADDED
      branch: finalBranch,
      visits: [firstVisit],
      visitDate: firstVisit.visitDate,
      purposeOfVisit: firstVisit.purposeOfVisit,
      numberOfVisit: 1,
      gold: gold || undefined,
      diamond: diamond || undefined,
      polki: polki || undefined,
      goldImages: goldImages.length > 0 ? goldImages : undefined,
      diamondImages: diamondImages.length > 0 ? diamondImages : undefined,
      polkiImages: polkiImages.length > 0 ? polkiImages : undefined,
      requirement: trimmedRequirement,
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
      reminder: finalReminder,
      conclusion: conclusion || "pending",
      birthday: birthday?.trim() || undefined,
      anniversary: anniversary?.trim() || undefined,
      profession: profession?.trim() || undefined,
      community: community?.trim() || undefined,
      referenceNote: referenceNote?.trim() || undefined,
      referredBy: finalReferredBy,
      assignedTo: assignedTo.trim(),
    });

    customer.customerClass = computeCustomerClass(customer);
    await customer.save();

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
      conclusion,
      whoAttend,
      helper,
      visitDate,
    } = req.body;

    const goldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
    const diamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
    const polkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    if (!customer.visits) {
      customer.visits = [];
    }

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

    const trimmedRequirement = requirement?.trim() || undefined;

    const newVisit = {
      visitNumber: customer.visits.length + 1,
      visitDate: visitDate ? new Date(visitDate) : new Date(),
      purposeOfVisit: purposeOfVisit?.trim() || undefined,
      gold: gold || undefined,
      diamond: diamond || undefined,
      polki: polki || undefined,
      goldImages: goldImages.length ? goldImages : undefined,
      diamondImages: diamondImages.length ? diamondImages : undefined,
      polkiImages: polkiImages.length ? polkiImages : undefined,
      requirement: trimmedRequirement,
      requirementStatus: trimmedRequirement ? "pending" : "none",
      conclusion: conclusion || "pending",
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
    };

    customer.visits.push(newVisit);
    customer.numberOfVisit = customer.visits.length;

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

// Update an EXISTING visit
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
      conclusion,
      whoAttend,
      helper,
      visitDate,
      removeGoldImages,
      removeDiamondImages,
      removePolkiImages,
    } = req.body;

    const newGoldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
    const newDiamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
    const newPolkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    let goldImages = visit.goldImages || [];
    let diamondImages = visit.diamondImages || [];
    let polkiImages = visit.polkiImages || [];

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

    if (requirement !== undefined) {
      const trimmed = requirement.trim();
      const previousText = visit.requirement;
      const previousStatus = visit.requirementStatus;

      visit.requirement = trimmed || undefined;

      if (!trimmed) {
        visit.requirementStatus = "none";
      } else if (previousStatus === "fulfilled" && previousText === trimmed) {
        visit.requirementStatus = "fulfilled";
      } else {
        visit.requirementStatus = "pending";
      }
    }

    if (conclusion !== undefined) visit.conclusion = conclusion;
    if (whoAttend !== undefined) visit.whoAttend = whoAttend.trim();
    if (helper !== undefined) visit.helper = helper.trim();
    if (visitDate) visit.visitDate = new Date(visitDate);

    visit.goldImages = goldImages.length ? goldImages : undefined;
    visit.diamondImages = diamondImages.length ? diamondImages : undefined;
    visit.polkiImages = polkiImages.length ? polkiImages : undefined;

    customer.visits[visitIndex] = visit;
    customer.markModified("visits");

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

// ✅ Mark a visit's requirement as fulfilled
exports.fulfillRequirement = async (req, res) => {
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
          message: "You can only update customers in your branch",
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

    if (visit.requirementStatus !== "pending") {
      return res.status(400).json({
        success: false,
        message: `This requirement is currently "${visit.requirementStatus}", not pending`,
      });
    }

    visit.requirementStatus = "fulfilled";
    visit.requirementFulfilledAt = new Date();
    customer.markModified("visits");
    await customer.save();

    res.json({
      success: true,
      message: "Requirement marked as fulfilled",
      data: customer,
    });
  } catch (err) {
    console.error("❌ Error fulfilling requirement:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to update requirement",
    });
  }
};

// ✅ Get all pending requirements across customers
exports.getPendingRequirements = async (req, res) => {
  try {
    const { category, search } = req.query;
    const filter = {};
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    } else if (req.query.branch) {
      filter.branch = req.query.branch;
    }

    const customers = await Customer.find(filter)
      .select("name phone email branch visits")
      .populate("branch", "name city");

    const results = [];
    customers.forEach((c) => {
      c.visits.forEach((v) => {
        if (v.requirementStatus !== "pending") return;
        if (category && !v[category]) return;
        if (search && !v.requirement?.toLowerCase().includes(search.toLowerCase())) return;

        results.push({
          customerId: c._id,
          name: c.name,
          phone: c.phone,
          email: c.email,
          branch: c.branch,
          visitNumber: v.visitNumber,
          requirement: v.requirement,
          category: { gold: v.gold, diamond: v.diamond, polki: v.polki },
          visitDate: v.visitDate,
        });
      });
    });

    res.json({ success: true, data: results });
  } catch (err) {
    console.error("❌ Error fetching pending requirements:", err);
    res.status(500).json({
      success: false,
      message: err.message || "Failed to fetch pending requirements",
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

exports.getDistinctProfessions = async (req, res) => {
  try {
    const filter = {};
    if (req.user && req.user.role === "admin" && req.user.branch) {
      filter.branch = req.user.branch;
    }
    filter.profession = { $ne: null, $ne: "" };

    const professions = await Customer.distinct("profession", filter);
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

// ==================== UPDATE CUSTOMER (FIXED) ====================

exports.updateCustomer = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    // Handle customer image
    const newCustomerImageFile = req.files?.customerImage?.[0];
    if (newCustomerImageFile) {
      updateData.customerImage = `uploads/customers/${newCustomerImageFile.filename}`;
    }

    // ✅ Handle additional info image
    const newAdditionalInfoImageFile = req.files?.additionalInfoImage?.[0];
    if (newAdditionalInfoImageFile) {
      updateData.additionalInfoImage = `uploads/customers/${newAdditionalInfoImageFile.filename}`;
    } else {
      // If the frontend sends null or empty string, remove the image
      if (updateData.additionalInfoImage === null || updateData.additionalInfoImage === '') {
        updateData.additionalInfoImage = null;
      }
      // If additionalInfoImage is not in the request at all, keep it as is
    }

    // Handle reminder logic
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

    // Handle optional fields
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
    // ✅ Handle additionalInfo
    if (updateData.additionalInfo !== undefined) {
      updateData.additionalInfo = updateData.additionalInfo?.trim() || undefined;
    }

    const existingCustomer = await Customer.findById(id);
    if (!existingCustomer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    // Branch permission check
    if (req.user && req.user.role === "admin" && req.user.branch) {
      const customerBranchId = existingCustomer.branch?._id?.toString() || existingCustomer.branch?.toString();
      if (customerBranchId !== req.user.branch.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only update customers in your branch",
        });
      }
      delete updateData.branch;
    }

    // Handle requirement update
    if (updateData.requirement !== undefined) {
      const trimmedRequirement = updateData.requirement?.trim() || undefined;

      if (existingCustomer.visits && existingCustomer.visits.length > 0) {
        const latestIndex = existingCustomer.visits.length - 1;
        const latestVisit = existingCustomer.visits[latestIndex];
        const previousText = latestVisit.requirement;
        const previousStatus = latestVisit.requirementStatus;

        latestVisit.requirement = trimmedRequirement;

        if (!trimmedRequirement) {
          latestVisit.requirementStatus = "none";
        } else if (previousStatus === "fulfilled" && previousText === trimmedRequirement) {
          latestVisit.requirementStatus = "fulfilled";
        } else {
          latestVisit.requirementStatus = "pending";
        }

        existingCustomer.markModified("visits");
        await existingCustomer.save();
      }

      updateData.requirement = trimmedRequirement;
    }

    // Remove fields that shouldn't be updated directly
    delete updateData.visits;
    delete updateData.numberOfVisit;

    console.log("📝 Updating customer with data:", JSON.stringify(updateData, null, 2));

    const customer = await Customer.findByIdAndUpdate(id, updateData, {
      new: true,
      runValidators: true,
      context: "query",
    })
      .populate("referredBy", "name phone")
      .populate("assignedTo", "name")
      .populate("branch", "name city");

    if (customer) {
      customer.customerClass = computeCustomerClass(customer);
      await customer.save();
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

    customer.visits.splice(visitIndex, 1);
    customer.numberOfVisit = customer.visits.length;

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
  fulfillRequirement: exports.fulfillRequirement,
  getPendingRequirements: exports.getPendingRequirements,
};