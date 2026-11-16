import { useEffect, useState } from "react";
import { addAvailability, delAvailability, getAvailability, updateAvailability } from "@/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Notice } from "@/components/ui/alert";
import { Select } from "@/components/ui/select";
import { WEEKDAYS, fmtDateLong, fmtTime, parseYmd, ymd } from "@/lib/dates";

function slotEnd(start) {
  const [hour, minute] = start.split(":").map(Number);
  const endMinutes = hour * 60 + minute + 30;
  return `${String(Math.floor(endMinutes / 60)).padStart(2, "0")}:${String(endMinutes % 60).padStart(2, "0")}`;
}

// Each availability entry is one independently bookable 30-minute slot.
export default function AvailabilityPanel({ onChange }) {
  const [items, setItems] = useState([]);
  const [mode, setMode] = useState("weekly");
  const [day, setDay] = useState("Mon");
  const [date, setDate] = useState(ymd(new Date()));
  const [start, setStart] = useState("09:00");
  const [editingId, setEditingId] = useState(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  const load = () => getAvailability().then(setItems).catch((e) => setError(e.message));
  useEffect(() => { load(); }, []);

  function edit(a) {
    setEditingId(a.availability_id);
    setMode(a.specific_date ? "date" : "weekly");
    setDay(a.day_of_week || "Mon");
    setDate(a.specific_date || ymd(new Date()));
    setStart(a.start_time.slice(0, 5));
    setError("");
  }

  function cancelEdit() {
    setEditingId(null);
    setMode("weekly");
    setDay("Mon");
    setDate(ymd(new Date()));
    setStart("09:00");
    setError("");
  }

  async function add(e) {
    e.preventDefault();
    setError("");
    setSaving(true);
    try {
      const body = { day_of_week: mode === "weekly" ? day : null, specific_date: mode === "date" ? date : null, start_time: start, end_time: slotEnd(start) };
      if (editingId) await updateAvailability(editingId, body);
      else await addAvailability(body);
      cancelEdit();
      await load();
      onChange && onChange();
    } catch (err) {
      setError(err.message);
    } finally {
      setSaving(false);
    }
  }
  async function remove(id) {
    setError("");
    try {
      await delAvailability(id);
      if (editingId === id) cancelEdit();
      await load();
      onChange && onChange();
    } catch (e) {
      setError(e.message);
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Open times</CardTitle>
        <CardDescription>Add each 30-minute slot separately. Choose another start time to leave a gap; for example, add 9:00 AM and 11:00 AM as two slots.</CardDescription>
      </CardHeader>
      <CardContent className="grid content-start gap-3">
        <form onSubmit={add} className="grid grid-cols-2 gap-2">
          <Select value={mode} onChange={(e) => setMode(e.target.value)}>
            <option value="weekly">Every week</option>
            <option value="date">One date only</option>
          </Select>
          {mode === "weekly" ? (
            <Select value={day} onChange={(e) => setDay(e.target.value)}>{WEEKDAYS.map((d) => <option key={d}>{d}</option>)}</Select>
          ) : (
            <Input type="date" value={date} min={ymd(new Date())} onChange={(e) => setDate(e.target.value)} required />
          )}
          <label className="col-span-2 grid gap-1.5 text-sm font-medium">
            Slot start time
            <Input type="time" value={start} min="00:00" max="23:29" step={60} onChange={(e) => setStart(e.target.value)} required />
          </label>
          <p className="col-span-2 text-xs text-muted-foreground">Choose any start minute. Each slot lasts 30 minutes: {fmtTime(start)}–{fmtTime(slotEnd(start))}.</p>
          <div className="col-span-2 flex gap-2">
            {editingId && <Button type="button" variant="outline" className="flex-1" onClick={cancelEdit}>Cancel edit</Button>}
            <Button type="submit" className="flex-1" disabled={saving}>{saving ? "Saving…" : editingId ? "Save changes" : "Add 30-minute slot"}</Button>
          </div>
        </form>
        {error && <Notice msg={{ type: "error", text: error }} />}
        <ul className="grid gap-2">
          {items.length === 0 && <li className="text-sm text-muted-foreground">No open times yet. Add individual slots so students can book you.</li>}
          {items.map((a) => (
            <li key={a.availability_id} className="flex flex-wrap items-center justify-between gap-2 rounded-xl bg-secondary px-3 py-2 text-sm">
              <span className="min-w-0 flex-1">{a.specific_date ? fmtDateLong(parseYmd(a.specific_date)) : `Every ${a.day_of_week}`} · {fmtTime(a.start_time)} – {fmtTime(a.end_time)}</span>
              <div className="flex shrink-0 items-center gap-1">
                <Button variant="ghost" size="sm" onClick={() => edit(a)}>Edit</Button>
                <Button variant="ghost" size="sm" className="text-destructive" onClick={() => remove(a.availability_id)}>Remove</Button>
              </div>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
