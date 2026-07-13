const Branch = require('../models/Branch');

// @desc   Create a new branch
// @route  POST /api/branches
exports.createBranch = async (req, res) => {
  try {
    const { name, address, city, state, phone } = req.body;

    if (!name || !address || !city) {
      return res.status(400).json({
        success: false,
        message: 'Name, address and city are required',
      });
    }

    const branch = await Branch.create({
      name,
      address,
      city,
      state,
      phone,
      createdBy: req.user?._id, // auth middleware se aata hai
    });

    res.status(201).json({
      success: true,
      message: 'Branch created successfully',
      branch,
    });
  } catch (error) {
    console.error('Create branch error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while creating branch',
    });
  }
};

// @desc   Get all branches
// @route  GET /api/branches
exports.getBranches = async (req, res) => {
  try {
    const branches = await Branch.find({ isActive: true }).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: branches.length,
      branches,
    });
  } catch (error) {
    console.error('Get branches error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching branches',
    });
  }
};

// @desc   Update a branch
// @route  PUT /api/branches/:id
exports.updateBranch = async (req, res) => {
  try {
    const branch = await Branch.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });

    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    res.status(200).json({ success: true, branch });
  } catch (error) {
    console.error('Update branch error:', error);
    res.status(500).json({ success: false, message: 'Server error while updating branch' });
  }
};

// @desc   Delete (soft-delete) a branch
// @route  DELETE /api/branches/:id
exports.deleteBranch = async (req, res) => {
  try {
    const branch = await Branch.findByIdAndUpdate(
      req.params.id,
      { isActive: false },
      { new: true }
    );

    if (!branch) {
      return res.status(404).json({ success: false, message: 'Branch not found' });
    }

    res.status(200).json({ success: true, message: 'Branch deleted successfully' });
  } catch (error) {
    console.error('Delete branch error:', error);
    res.status(500).json({ success: false, message: 'Server error while deleting branch' });
  }
};