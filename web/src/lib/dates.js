// Maliliit na tulong sa petsa at oras (walang dagdag na library)
export const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
export const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const pad = (n) => String(n).padStart(2, "0");

export const ymd = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export const parseYmd = (s) => { const [y, m, d] = s.split("-").map(Number); return new Date(y, m - 1, d); };
export const addDays = (d, n) => { const x = new Date(d); x.setDate(x.getDate() + n); return x; };
export const startOfWeek = (d) => addDays(d, -((d.getDay() + 6) % 7)); // Lunes ang simula
export const sameDay = (a, b) => ymd(a) === ymd(b);

// 6 na linggo (42 araw) para sa month grid
export function monthGrid(d) {
  const first = new Date(d.getFullYear(), d.getMonth(), 1);
  const start = startOfWeek(first);
  return Array.from({ length: 42 }, (_, i) => addDays(start, i));
}

export function fmtTime(hhmm) {
  const [h, m] = hhmm.split(":").map(Number);
  return `${h % 12 || 12}:${pad(m)} ${h < 12 ? "AM" : "PM"}`;
}
export const fmtDateLong = (d) => `${WEEKDAYS[(d.getDay() + 6) % 7]}, ${MONTHS[d.getMonth()].slice(0, 3)} ${d.getDate()}`;
export const firstName = (name) => (name || "").replace(/^(Engr\.|Dr\.|Prof\.)\s+/i, "").split(" ")[0];
export const fmtSize = (n) => (n > 1048576 ? `${(n / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(n / 1024))} KB`);
