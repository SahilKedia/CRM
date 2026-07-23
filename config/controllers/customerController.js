// backend/controllers/customerController.js
const Customer = require("../models/Customer");
// const Employee = require("../models/Employee");   // NOTIFICATION: commented
// const Notification = require("../models/Notification"); // NOTIFICATION: commented
const { createAndSendFeedbackRequest } = require("./feedbackController");

// ==================== BRANCH SCOPING HELPER ====================
// Superadmin always sees everything.
// Any other role (admin OR employee) that has a branch attached is
// restricted to that branch. Previously only "admin" was checked here,
// which meant employees could view/edit/delete customers across ALL
// branches — this closes that gap.
function userIsBranchScoped(req) {
  return !!(req.user && req.user.branch && req.user.role !== "superadmin");
}

// ==================== VIP / CUSTOMER CLASS LOGIC ====================
// Conclusions now live per jewelry item (goldItems / diamondItems / polkiItems),
// not on the visit as a whole, so we count across all items in all visits.
function computeCustomerClass(customerDoc) {
  if (customerDoc.manualClassOverride) return customerDoc.manualClassOverride;

  const visits = customerDoc.visits || [];
  const numberOfVisit = customerDoc.numberOfVisit || visits.length || 1;

  let totalItems = 0;
  let soldItems = 0;

  visits.forEach((v) => {
    ["goldItems", "diamondItems", "polkiItems"].forEach((key) => {
      (v[key] || []).forEach((item) => {
        totalItems++;
        if (item.conclusion === "sold") soldItems++;
      });
    });
  });

  const hasProfession = !!(customerDoc.profession && customerDoc.profession.trim());

  if (soldItems >= 1 && totalItems >= 5) return "Big Spender";
  if (numberOfVisit >= 5) return "Loyal";
  if (hasProfession && numberOfVisit >= 2) return "VIP";
  return "Regular";
}

// ==================== JEWELRY ITEM HELPERS ====================
// Frontend contract for multi-item, multi-conclusion visits:
//
// Send a JSON string per category, e.g. `goldItems`:
//   [
//     { "description": "Ring", "weight": "10g", "conclusion": "sold", "remarks": "...", "imageCount": 2 },
//     { "description": "Necklace", "conclusion": "on order", "imageCount": 0 }
//   ]
// and upload the actual files under the existing flat field name (e.g. `goldImages`),
// in the SAME ORDER the items appear, `imageCount` files per item.
//
// For updates, each item may include `_id` (to edit an existing item instead of
// creating a new one), `existingImages` (URLs to keep), and `newImageCount`
// (how many of the newly uploaded files, in order, belong to this item).

function safeParseItems(raw) {
  if (!raw) return null;
  if (Array.isArray(raw)) return raw;
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : null;
  } catch (e) {
    return null;
  }
}

// Build a brand-new items array (used for addCustomer / addVisit).
// Falls back to a single legacy item if only the old flat string field was sent.
function buildNewItems(itemsRaw, uploadedFiles, legacySingleValue) {
  let itemsMeta = safeParseItems(itemsRaw);

  if (!itemsMeta) {
    if (legacySingleValue && legacySingleValue.trim()) {
      itemsMeta = [
        {
          description: legacySingleValue.trim(),
          conclusion: "pending",
          imageCount: uploadedFiles.length,
        },
      ];
    } else {
      itemsMeta = [];
    }
  }

  let cursor = 0;
  const items = itemsMeta
    .filter((it) => it && it.description && String(it.description).trim())
    .map((it) => {
      const count = Number.isInteger(it.imageCount) ? it.imageCount : 0;
      const images = uploadedFiles.slice(cursor, cursor + count);
      cursor += count;
      return {
        description: String(it.description).trim(),
        weight: it.weight?.toString().trim() || undefined,
        conclusion: it.conclusion || "pending",
        remarks: it.remarks?.toString().trim() || undefined,
        images: images.length ? images : undefined,
      };
    });

  // Don't silently drop any uploaded files that weren't accounted for.
  if (cursor < uploadedFiles.length && items.length > 0) {
    const leftover = uploadedFiles.slice(cursor);
    const last = items[items.length - 1];
    last.images = [...(last.images || []), ...leftover];
  }

  return items;
}

// Build an updated items array (used for updateVisit), merging against the
// visit's existing items so edits, new items, and removals all work.
// Returns `undefined` if the category wasn't sent at all (meaning: leave it untouched).
function buildUpdatedItems(existingItems, itemsRaw, uploadedFiles) {
  const itemsMeta = safeParseItems(itemsRaw);
  if (itemsMeta === null) return undefined; // category not sent — don't touch it

  const existingById = new Map(
    (existingItems || [])
      .filter((it) => it && it._id)
      .map((it) => [it._id.toString(), it])
  );

  let cursor = 0;
  const result = itemsMeta
    .filter((it) => it && it.description && String(it.description).trim())
    .map((it) => {
      const count = Number.isInteger(it.newImageCount) ? it.newImageCount : 0;
      const newImages = uploadedFiles.slice(cursor, cursor + count);
      cursor += count;

      const keptImages = Array.isArray(it.existingImages) ? it.existingImages : [];
      const images = [...keptImages, ...newImages];

      const matchedExisting = it._id ? existingById.get(String(it._id)) : undefined;

      return {
        _id: matchedExisting ? matchedExisting._id : undefined,
        description: String(it.description).trim(),
        weight: it.weight?.toString().trim() || undefined,
        conclusion: it.conclusion || matchedExisting?.conclusion || "pending",
        remarks: it.remarks?.toString().trim() || undefined,
        images: images.length ? images : undefined,
      };
    });

  if (cursor < uploadedFiles.length && result.length > 0) {
    const leftover = uploadedFiles.slice(cursor);
    const last = result[result.length - 1];
    last.images = [...(last.images || []), ...leftover];
  }

  return result;
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
      gold, // legacy single-value fallback
      diamond, // legacy single-value fallback
      polki, // legacy single-value fallback
      goldItems, // JSON string: [{ description, weight, conclusion, remarks, imageCount }]
      diamondItems,
      polkiItems,
      requirement,
      whoAttend,
      helper,
      reminderDate,
      reminderMessage,
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

    // Build item arrays — each item carries its own description + conclusion,
    // e.g. gold "Ring" -> sold, diamond "Ring" -> on order, in the same visit.
    const goldItemsBuilt = buildNewItems(goldItems, goldImages, gold);
    const diamondItemsBuilt = buildNewItems(diamondItems, diamondImages, diamond);
    const polkiItemsBuilt = buildNewItems(polkiItems, polkiImages, polki);

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
      goldItems: goldItemsBuilt.length ? goldItemsBuilt : undefined,
      diamondItems: diamondItemsBuilt.length ? diamondItemsBuilt : undefined,
      polkiItems: polkiItemsBuilt.length ? polkiItemsBuilt : undefined,
      requirement: trimmedRequirement,
      requirementStatus: trimmedRequirement ? "pending" : "none",
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
      goldItems: firstVisit.goldItems,
      diamondItems: firstVisit.diamondItems,
      polkiItems: firstVisit.polkiItems,
      requirement: trimmedRequirement,
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
      reminder: finalReminder,
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

    if (userIsBranchScoped(req)) {
      if (customer.branch?.toString() !== req.user.branch?.toString()) {
        return res.status(403).json({
          success: false,
          message: "You can only add visits for customers in your branch",
        });
      }
    }

    const {
      purposeOfVisit,
      gold, // legacy single-value fallback
      diamond, // legacy single-value fallback
      polki, // legacy single-value fallback
      goldItems,
      diamondItems,
      polkiItems,
      requirement,
      whoAttend,
      helper,
      visitDate,
    } = req.body;

    const goldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
    const diamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
    const polkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    const goldItemsBuilt = buildNewItems(goldItems, goldImages, gold);
    const diamondItemsBuilt = buildNewItems(diamondItems, diamondImages, diamond);
    const polkiItemsBuilt = buildNewItems(polkiItems, polkiImages, polki);

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
      goldItems: goldItemsBuilt.length ? goldItemsBuilt : undefined,
      diamondItems: diamondItemsBuilt.length ? diamondItemsBuilt : undefined,
      polkiItems: polkiItemsBuilt.length ? polkiItemsBuilt : undefined,
      requirement: trimmedRequirement,
      requirementStatus: trimmedRequirement ? "pending" : "none",
      whoAttend: whoAttend?.trim() || undefined,
      helper: helper?.trim() || undefined,
    };

    customer.visits.push(newVisit);
    customer.numberOfVisit = customer.visits.length;

    const latestVisit = customer.visits[customer.visits.length - 1];
    customer.visitDate = latestVisit.visitDate;
    customer.purposeOfVisit = latestVisit.purposeOfVisit;
    customer.goldItems = latestVisit.goldItems;
    customer.diamondItems = latestVisit.diamondItems;
    customer.polkiItems = latestVisit.polkiItems;
    customer.requirement = latestVisit.requirement;
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

    if (userIsBranchScoped(req)) {
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
      // Per-category JSON array of items, e.g.:
      // [{ "_id": "...", "description": "Ring", "conclusion": "sold",
      //    "existingImages": [...], "newImageCount": 1 }, { ...new item, no _id... }]
      goldItems,
      diamondItems,
      polkiItems,
      requirement,
      whoAttend,
      helper,
      visitDate,
    } = req.body;

    const newGoldImages = (req.files?.goldImages || []).map((f) => `uploads/customers/${f.filename}`);
    const newDiamondImages = (req.files?.diamondImages || []).map((f) => `uploads/customers/${f.filename}`);
    const newPolkiImages = (req.files?.polkiImages || []).map((f) => `uploads/customers/${f.filename}`);

    // buildUpdatedItems returns undefined when the category wasn't sent at all,
    // meaning "leave this category's items untouched" — otherwise it fully
    // replaces the category with the (possibly edited/added/removed) item list.
    const updatedGoldItems = buildUpdatedItems(visit.goldItems, goldItems, newGoldImages);
    const updatedDiamondItems = buildUpdatedItems(visit.diamondItems, diamondItems, newDiamondImages);
    const updatedPolkiItems = buildUpdatedItems(visit.polkiItems, polkiItems, newPolkiImages);

    if (purposeOfVisit !== undefined) visit.purposeOfVisit = purposeOfVisit.trim();
    if (updatedGoldItems !== undefined) visit.goldItems = updatedGoldItems.length ? updatedGoldItems : undefined;
    if (updatedDiamondItems !== undefined) visit.diamondItems = updatedDiamondItems.length ? updatedDiamondItems : undefined;
    if (updatedPolkiItems !== undefined) visit.polkiItems = updatedPolkiItems.length ? updatedPolkiItems : undefined;

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

    if (whoAttend !== undefined) visit.whoAttend = whoAttend.trim();
    if (helper !== undefined) visit.helper = helper.trim();
    if (visitDate) visit.visitDate = new Date(visitDate);

    customer.visits[visitIndex] = visit;
    customer.markModified("visits");

    if (visitIndex === customer.visits.length - 1) {
      customer.visitDate = visit.visitDate;
      customer.purposeOfVisit = visit.purposeOfVisit;
      customer.goldItems = visit.goldItems;
      customer.diamondItems = visit.diamondItems;
      customer.polkiItems = visit.polkiItems;
      customer.requirement = visit.requirement;
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

    if (userIsBranchScoped(req)) {
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
    if (userIsBranchScoped(req)) {
      filter.branch = req.user.branch;
    } else if (req.query.branch) {
      filter.branch = req.query.branch;
    }

    const customers = await Customer.find(filter)
      .select("name phone email branch visits")
      .populate("branch", "name city");

    // category filter now refers to an items array (goldItems/diamondItems/polkiItems)
    const categoryKey = category
      ? (category.endsWith("Items") ? category : `${category}Items`)
      : null;

    const results = [];
    customers.forEach((c) => {
      c.visits.forEach((v) => {
        if (v.requirementStatus !== "pending") return;
        if (categoryKey && !(v[categoryKey] && v[categoryKey].length)) return;
        if (search && !v.requirement?.toLowerCase().includes(search.toLowerCase())) return;

        results.push({
          customerId: c._id,
          name: c.name,
          phone: c.phone,
          email: c.email,
          branch: c.branch,
          visitNumber: v.visitNumber,
          requirement: v.requirement,
          items: {
            gold: v.goldItems || [],
            diamond: v.diamondItems || [],
            polki: v.polkiItems || [],
          },
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

    if (userIsBranchScoped(req)) {
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

    if (userIsBranchScoped(req)) {
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
    if (userIsBranchScoped(req)) {
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
    if (userIsBranchScoped(req)) {
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
    if (userIsBranchScoped(req)) {
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

    if (userIsBranchScoped(req)) {
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

    if (userIsBranchScoped(req)) {
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

    if (userIsBranchScoped(req)) {
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
      customer.goldItems = latestVisit.goldItems;
      customer.diamondItems = latestVisit.diamondItems;
      customer.polkiItems = latestVisit.polkiItems;
      customer.requirement = latestVisit.requirement;
      customer.whoAttend = latestVisit.whoAttend;
      customer.helper = latestVisit.helper;
    } else {
      customer.visitDate = undefined;
      customer.purposeOfVisit = undefined;
      customer.goldItems = undefined;
      customer.diamondItems = undefined;
      customer.polkiItems = undefined;
      customer.requirement = undefined;
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