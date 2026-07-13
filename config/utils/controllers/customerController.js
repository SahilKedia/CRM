const Customer = require("../models/Customer");

// Add Customer (branch comes from the logged-in user unless a super-admin picks one)
exports.addCustomer = async (req, res) => {
  try {
    const {
      name, email, phone, address,
      visitDate, purposeOfVisit,
      gold, diamond, polki,
      requirement, approval, whoAttend,
      helper, reminder, media,
      conclusion, status, notes, assignedTo,
    } = req.body;

    let { branch } = req.body;

    // Employee ya branch-admin sirf apni hi branch ke liye customer visit add
    // kar sakta hai - body mein aayi branch ko ignore karke apni branch use hogi.
    if (req.user && req.user.branch) {
      branch = req.user.branch;
    }

    if (!branch) {
      return res.status(400).json({
        success: false,
        message: "Branch is required",
      });
    }

    if (!name || !assignedTo) {
      return res.status(400).json({
        success: false,
        message: "Name and assigned employee are required",
      });
    }

    // Build image URLs from uploaded files
    const baseUrl = `${req.protocol}://${req.get("host")}/uploads/customers`;

    const goldImages = (req.files?.goldImages || []).map(
      (f) => `${baseUrl}/${f.filename}`
    );
    const diamondImages = (req.files?.diamondImages || []).map(
      (f) => `${baseUrl}/${f.filename}`
    );
    const polkiImages = (req.files?.polkiImages || []).map(
      (f) => `${baseUrl}/${f.filename}`
    );

    const customer = await Customer.create({
      name, email, phone, address,
      branch,
      visitDate, purposeOfVisit,
      gold, diamond, polki,
      goldImages, diamondImages, polkiImages,
      requirement, approval, whoAttend,
      helper, reminder, media,
      conclusion, status, notes, assignedTo,
    });

    res.status(201).json({
      success: true,
      message: "Customer Added Successfully",
      customer,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Get All Customers - branch-scoped for employees / branch-admins
exports.getCustomers = async (req, res) => {
  try {
    const filter = {};

    if (req.user && req.user.branch) {
      filter.branch = req.user.branch;
    } else if (req.query.branch) {
      // Super admin can optionally filter by branch via ?branch=xxx
      filter.branch = req.query.branch;
    }

    const customers = await Customer.find(filter)
      .populate("assignedTo", "name email position")
      .sort({ createdAt: -1 });

    res.status(200).json({ success: true, customers });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Update Customer
exports.updateCustomer = async (req, res) => {
  try {
    const customer = await Customer.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    }).populate("assignedTo", "name email position");

    if (!customer) {
      return res.status(404).json({ success: false, message: "Customer not found" });
    }

    res.status(200).json({
      success: true,
      message: "Customer Updated Successfully",
      customer,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// Delete Customer
exports.deleteCustomer = async (req, res) => {
  try {
    const customer = await Customer.findByIdAndDelete(req.params.id);

    if (!customer) {
      return res.status(404).json({
        success: false,
        message: "Customer not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Customer Deleted Successfully",
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};
