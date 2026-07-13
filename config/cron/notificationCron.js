const cron = require('node-cron');
const Customer = require('../models/Customer');
const Employee = require('../models/Employee');
const Notification = require('../models/Notification');
const { toDateKey, parseDDMM, daysUntilNextOccurrence, formatCountdown } = require('../utils/dateHelpers');

// Atomic create-if-not-exists. dateKey is derived from `date`, so calling
// this many times for the same event/day never creates duplicates.
async function upsertNotification({ userId, customerId, type, title, message, date }) {
  const dateKey = toDateKey(date);
  try {
    await Notification.findOneAndUpdate(
      { userId, customerId, type, dateKey },
      { $setOnInsert: { title, message, date, userId, customerId, type, dateKey } },
      { upsert: true, new: true }
    );
    return true;
  } catch (err) {
    if (err.code === 11000) return false; // race with another process, fine
    console.error('❌ upsertNotification error:', err.message);
    return false;
  }
}

// ---------- Birthdays & anniversaries (fires once per day, within 7 days out) ----------
async function createSpecialDayNotifications() {
  try {
    console.log('🔄 Running special day notification check...');
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const customers = await Customer.find({
      $or: [
        { birthday: { $exists: true, $ne: null, $ne: "" } },
        { anniversary: { $exists: true, $ne: null, $ne: "" } }
      ]
    });

    const employees = await Employee.find({});
    let created = 0;

    for (const customer of customers) {
      for (const [field, type, emoji, label] of [
        ['birthday', 'birthday', '🎂', 'Birthday'],
        ['anniversary', 'anniversary', '💍', 'Anniversary']
      ]) {
        const raw = customer[field];
        if (!raw) continue;

        const parsed = parseDDMM(raw);
        if (!parsed) continue;

        const daysAway = daysUntilNextOccurrence(parsed.day, parsed.month, today);
        if (daysAway < 0 || daysAway > 7) continue;

        const countdown = formatCountdown(daysAway);
        const title = daysAway === 0 ? `${emoji} ${label} Today!` : `${emoji} Upcoming ${label}`;
        const message = `${customer.name} — this customer's ${field} is ${countdown}.`;

        for (const employee of employees) {
          const wasCreated = await upsertNotification({
            userId: employee._id,
            customerId: customer._id,
            type,
            title,
            message,
            date: today
          });
          if (wasCreated) created++;
        }
      }
    }

    console.log(`✅ Special day check complete. ${created} new notifications created.`);
    return created;
  } catch (error) {
    console.error('❌ Error creating special day notifications:', error);
    return 0;
  }
}

// ---------- Delivery / task reminders (fires ONLY once reminder.date has actually arrived) ----------
async function createReminderNotifications() {
  try {
    console.log('🔄 Running reminder-due check...');
    const now = new Date();

    // Find customers that have at least one visit with a pending reminder whose date has arrived
    const customers = await Customer.find({
      'visits.reminder.status': 'pending',
      'visits.reminder.date': { $ne: null, $lte: now }
    }).populate('assignedTo', '_id branch');

    let created = 0;

    for (const customer of customers) {
      if (!customer.assignedTo) continue;

      // Find all visits for this customer that have pending reminders due now
      const dueVisits = customer.visits.filter(
        v => v.reminder && v.reminder.status === 'pending' && v.reminder.date && v.reminder.date <= now
      );

      if (dueVisits.length === 0) continue;

      // Get admins for the branch (once per customer)
      const admins = await Employee.find({ branch: customer.branch, role: 'admin' }).select('_id');
      const adminIds = admins.map(a => String(a._id));

      for (const visit of dueVisits) {
        const dueDate = visit.reminder.date;
        const title = '⏰ Reminder Due';
        const message = `Reminder for ${customer.name} (Visit #${visit.visitNumber}): ${visit.reminder.note || 'Follow up now'}.`;

        // Recipients: assigned employee + admins in the same branch
        const recipientIds = new Set([String(customer.assignedTo._id)]);
        adminIds.forEach(id => recipientIds.add(id));

        for (const userId of recipientIds) {
          // Use the reminder's due date as dateKey to avoid duplicates
          const wasCreated = await upsertNotification({
            userId,
            customerId: customer._id,
            type: 'reminder',
            title,
            message,
            date: dueDate
          });
          if (wasCreated) created++;
        }
      }
    }

    console.log(`✅ Reminder check complete. ${created} new notifications created.`);
    return created;
  } catch (error) {
    console.error('❌ Error creating reminder notifications:', error);
    return 0;
  }
}

function initNotificationCron() {
  console.log('⏰ Setting up notification cron jobs...');

  // Birthdays/anniversaries: twice a day is enough, dates don't change fast
  cron.schedule('0 9 * * *', async () => {
    console.log('🕘 ===== SCHEDULED SPECIAL-DAY CHECK (9:00 AM) =====');
    await createSpecialDayNotifications();
  });
  cron.schedule('0 18 * * *', async () => {
    console.log('🕕 ===== SCHEDULED SPECIAL-DAY CHECK (6:00 PM) =====');
    await createSpecialDayNotifications();
  });

  // Reminders need date+time precision, so check frequently
  cron.schedule('*/5 * * * *', async () => {
    console.log('⏱️ ===== SCHEDULED REMINDER CHECK (every 5 min) =====');
    await createReminderNotifications();
  });

  setTimeout(async () => {
    console.log('🚀 ===== INITIAL NOTIFICATION CHECK =====');
    await createSpecialDayNotifications();
    await createReminderNotifications();
  }, 15000);

  console.log('✅ Notification cron jobs setup complete');
}

module.exports = {
  initNotificationCron,
  createSpecialDayNotifications,
  createReminderNotifications
};