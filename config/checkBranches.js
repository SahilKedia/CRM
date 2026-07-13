require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');
const Customer = require('./models/Customer');

async function run() {
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/crm');

  const admins = await User.find({ role: 'admin' }).select('name email branch');
  console.log('👤 Admins:', admins.map(a => ({ name: a.name, branch: a.branch?.toString() })));

  const customers = await Customer.find({}).select('name branch');
  console.log('👥 Customers:', customers.map(c => ({ name: c.name, branch: c.branch?.toString() })));

  await mongoose.disconnect();
}

run();