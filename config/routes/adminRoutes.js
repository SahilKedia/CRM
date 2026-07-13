const express = require('express');
const router = express.Router();
const { 
  getAllAdmins, 
  updateAdmin, 
  deleteAdmin 
} = require('../controllers/authController'); // or where they are exported

// GET all admins (role = 'admin')
router.get('/', getAllAdmins);

// PUT update admin
router.put('/:id', updateAdmin);

// DELETE admin
router.delete('/:id', deleteAdmin);

module.exports = router;