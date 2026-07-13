const express = require('express');
const router = express.Router();
const {
  createBranch,
  getBranches,
  updateBranch,
  deleteBranch,
} = require('../controllers/branchController');

const { protect, restrictTo } = require('../middleware/auth');

// ✅ PUBLIC - Anyone can view branches (no authentication needed)
router.get('/', getBranches);

// 🔒 PROTECTED - Only admins can create/update/delete
router.post('/', protect, restrictTo('admin'), createBranch);
router.put('/:id', protect, restrictTo('admin'), updateBranch);
router.delete('/:id', protect, restrictTo('admin'), deleteBranch);

module.exports = router;