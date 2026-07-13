// const Joi = require('joi');

// const visitSchema = Joi.object({
//   visitDate: Joi.date(),
//   purposeOfVisit: Joi.string().required(),
//   jewelleryDetails: Joi.object({
//     gold: Joi.object({ description: Joi.string(), images: Joi.array().items(Joi.string().uri()) }),
//     diamond: Joi.object({ description: Joi.string(), images: Joi.array().items(Joi.string().uri()) }),
//     polki: Joi.object({ description: Joi.string(), images: Joi.array().items(Joi.string().uri()) })
//   }),
//   staffAttended: Joi.string().optional(), // could be ObjectId or name
//   requirementApproval: Joi.boolean(),
//   conclusion: Joi.string().valid('shortlisted', 'sold', 'just see'),
//   reminder: Joi.object({
//     date: Joi.date(),
//     time: Joi.string().pattern(/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/),
//     message: Joi.string()
//   })
// });

// const customerSchema = Joi.object({
//   name: Joi.string().required(),
//   phone: Joi.string().required(),
//   gmail: Joi.string().email().required(),
//   address: Joi.string(),
//   profession: Joi.string(),
//   community: Joi.string(),
//   birthday: Joi.object({
//     month: Joi.number().integer().min(1).max(12),
//     day: Joi.number().integer().min(1).max(31)
//   }),
//   anniversary: Joi.object({
//     month: Joi.number().integer().min(1).max(12),
//     day: Joi.number().integer().min(1).max(31)
//   }),
//   referenceText: Joi.string(),
//   referredCustomers: Joi.array().items(Joi.string().hex().length(24)), // ObjectId hex
//   visit: visitSchema // for creation
// });

// exports.validateCustomer = (req, res, next) => {
//   const { error } = customerSchema.validate(req.body);
//   if (error) return res.status(400).json({ success: false, error: error.details[0].message });
//   next();
// };

// exports.validateVisit = (req, res, next) => {
//   const { error } = visitSchema.validate(req.body);
//   if (error) return res.status(400).json({ success: false, error: error.details[0].message });
//   next();
// };