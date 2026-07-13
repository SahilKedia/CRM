const Profession = require('../models/Profession');

exports.getProfessions = async (req, res) => {
  try {
    const professions = await Profession.find().sort('name');
    res.json({ success: true, data: professions });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

exports.createProfession = async (req, res) => {
  try {
    const { name } = req.body;
    const profession = await Profession.create({ name });
    res.status(201).json({ success: true, data: profession });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};