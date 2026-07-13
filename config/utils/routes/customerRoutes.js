// routes/customerRoutes.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const customerController = require('../controllers/customerController');
const { protect } = require('../middleware/auth');

// Configure storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/customers'); // make sure this folder exists
  },
  filename: (req, file, cb) => {
    cb(null, `${Date.now()}-${file.originalname}`);
  },
});

const upload = multer({ storage });

// IMPORTANT: multer.fields() must run BEFORE your controller
router.post(
  '/',
  protect,
  upload.fields([
    { name: 'goldImages', maxCount: 5 },
    { name: 'diamondImages', maxCount: 5 },
    { name: 'polkiImages', maxCount: 5 },
  ]),
  customerController.addCustomer
);

router.get('/', protect, customerController.getCustomers);
router.put('/customers/:id', protect, customerController.updateCustomer);
router.delete('/customers/:id', protect, customerController.deleteCustomer);

module.exports = router;