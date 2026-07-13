function toDateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function parseDDMM(str) {
  const parts = str.split('-').map(Number);
  if (parts.length !== 2 || parts.some(isNaN)) return null;
  return { day: parts[0], month: parts[1] };
}

function daysUntilNextOccurrence(day, month, today) {
  const thisYear = new Date(today.getFullYear(), month - 1, day);
  thisYear.setHours(0, 0, 0, 0);
  if (thisYear < today) {
    thisYear.setFullYear(today.getFullYear() + 1);
  }
  return Math.round((thisYear - today) / (1000 * 60 * 60 * 24));
}

// "today" / "tomorrow" / "in 1 week" / "in 5 days"
function formatCountdown(daysAway) {
  if (daysAway === 0) return 'today';
  if (daysAway === 1) return 'tomorrow';
  if (daysAway === 7) return 'in 1 week';
  return `in ${daysAway} days`;
}

module.exports = { toDateKey, parseDDMM, daysUntilNextOccurrence, formatCountdown };