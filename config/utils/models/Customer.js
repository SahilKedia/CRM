// backend/models/Customer.js
const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Name is required'],
    trim: true
  },
  email: {
    type: String,
    trim: true,
    lowercase: true
  },
  phone: {
    type: String,
    trim: true
  },
  address: {
    type: String,
    trim: true
  },
  branch: {
    type: String,
    required: [true, 'Branch is required'],
    trim: true
  },
  visitDate: {
    type: Date,
    default: Date.now
  },
  purposeOfVisit: {
    type: String,
    trim: true
  },
  gold: {
    type: String,
    trim: true
  },
  diamond: {
    type: String,
    trim: true
  },
  polki: {
    type: String,
    trim: true
  },
  goldImages: [{
    type: String
  }],
  diamondImages: [{
    type: String
  }],
  polkiImages: [{
    type: String
  }],
  requirement: {
    type: String,
    trim: true
  },
  approval: {
    type: String,
    trim: true
  },
  whoAttend: {
    type: String,
    trim: true
  },
  helper: {
    type: String,
    trim: true
  },
  reminder: {
    type: Date
  },
  media: {
    type: String,
    trim: true
  },
  conclusion: {
    type: String,
    enum: ['Sold', 'Shortlisted', 'Just See', 'On Order', 'On Approval', 'Pending'],
    default: 'Pending'
  },
  status: {
    type: String,
    enum: ['Active', 'Inactive', 'Lead', 'Prospect', 'Vendor'],
    default: 'Lead'
  },
  notes: {
    type: String,
    trim: true
  },
  assignedTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Employee',
    required: [true, 'Please assign an employee']
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Customer', customerSchema);