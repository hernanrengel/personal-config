import { google } from 'googleapis';
import { readFileSync } from 'fs';

const creds = JSON.parse(readFileSync('./google_credentials.json'));
const token = JSON.parse(readFileSync('./google_token.json'));
const { client_id, client_secret } = creds.web;

const auth = new google.auth.OAuth2(client_id, client_secret, 'http://localhost:9876/callback');
auth.setCredentials(token);

const calendar = google.calendar({ version: 'v3', auth });

// List all calendars
const { data: { items: calendars } } = await calendar.calendarList.list();
console.log(`\nCalendarios encontrados (${calendars.length}):`);
calendars.forEach(c => console.log(`  - ${c.summary} [${c.id}]`));

// Get events for today and next 7 days
const now = new Date();
const nextWeek = new Date();
nextWeek.setDate(now.getDate() + 7);

console.log(`\n===== Próximos 7 días =====`);

// Fetch events from all calendars in parallel
const allEvents = [];
await Promise.all(calendars.map(async cal => {
  try {
    const { data: { items } } = await calendar.events.list({
      calendarId: cal.id,
      timeMin: now.toISOString(),
      timeMax: nextWeek.toISOString(),
      singleEvents: true,
      maxResults: 50,
    });
    items.forEach(e => allEvents.push({ ...e, calendarName: cal.summary }));
  } catch (_) {}
}));

// Sort by start time
allEvents.sort((a, b) => {
  const aStart = a.start.dateTime || a.start.date;
  const bStart = b.start.dateTime || b.start.date;
  return new Date(aStart) - new Date(bStart);
});

if (allEvents.length === 0) {
  console.log('No hay eventos próximos.');
} else {
  let lastDate = '';
  allEvents.forEach(e => {
    const start = e.start.dateTime || e.start.date;
    const date = new Date(start);
    const dateStr = date.toLocaleDateString('es', { weekday: 'long', month: 'long', day: 'numeric' });

    if (dateStr !== lastDate) {
      console.log(`\n${dateStr.toUpperCase()}`);
      lastDate = dateStr;
    }

    const timeStr = e.start.dateTime
      ? date.toLocaleTimeString('es', { hour: '2-digit', minute: '2-digit' })
      : 'Todo el día';

    const cal = e.calendarName !== 'hrengelc@gmail.com' ? ` [${e.calendarName}]` : '';
    console.log(`  ${timeStr} — ${e.summary}${e.location ? ` @ ${e.location}` : ''}${cal}`);
  });
}
