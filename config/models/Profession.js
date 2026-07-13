const mongoose = require('mongoose');
const professionSchema = new mongoose.Schema({
  name: { type: String, unique: true, required: true }
});
module.exports = mongoose.model('Profession', professionSchema);