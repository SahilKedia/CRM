const express = require('express');
const router = express.Router();
const professionController = require('../controllers/professionController');

router.get('/', professionController.getProfessions);
router.post('/', professionController.createProfession);

module.exports = router;