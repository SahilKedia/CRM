const mongoose = require('mongoose');
const communitySchema = new mongoose.Schema({
  name: { type: String, unique: true, required: true }
});
module.exports = mongoose.model('Community', communitySchema);