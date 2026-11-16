import { useEffect, useState } from "react";
import { getSlots } from "@/api";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { fmtDateLong, fmtTime, ymd } from "@/lib/dates";

// Ginagamit sa pag-book at sa pag-reschedule. Ang student ay pumipili lang ng petsa at oras;
// ang adviser ang magse-set kung online o in-person at saan.
export default function BookingDialog({
  adviser, open, onOpenChange, onSubmit, onDone,
  title = `Book ${adviser.name}`,
  description = "Pick a date and time. Your adviser will tell you if it will be online or in person.",
  confirmLabel = "Confirm booking", showNotes = true, initialDate, initialStart,
}) {
  const [date, setDate] = useState(initialDate || new Date());
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(false);
  const [start, setStart] = useState("");
  const [notes, setNotes] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!open) return;
    setDate(initialDate || new Date());
    setStart(initialStart || "");
    setNotes("");
    setError("");
  }, [open, initialDate && ymd(initialDate), initialStart]);

  const loadSlots = () => {
    setLoading(true);
    getSlots(adviser.adviser_id, ymd(date), ymd(date))
      .then(setSlots)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  };
  useEffect(() => {
    if (!open) return;
    setError("");
    setStart(initialDate && ymd(date) === ymd(initialDate) ? initialStart || "" : "");
    loadSlots();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, date, initialDate && ymd(initialDate), initialStart]);

  async function submit(e) {
    e.preventDefault();
    if (!start) { setError("Pick a time first."); return; }
    if (showNotes && !notes.trim()) { setError("Please tell us what you will discuss."); return; }
    setBusy(true);
    setError("");
    try {
      await onSubmit(ymd(date), start, notes.trim());
      setNotes("");
      onDone(date);
    } catch (err) {
      setError(err.message);
      loadSlots(); // i-refresh kung may nakakuha na ng slot
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{description}</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4">
          <Calendar mode="single" selected={date} onSelect={(d) => d && setDate(d)} disabled={{ before: new Date() }} defaultMonth={date} />
          <div className="grid gap-2">
            <Label>Open times · {fmtDateLong(date)}</Label>
            {loading && <p className="text-sm text-muted-foreground">Loading…</p>}
            {!loading && slots.length === 0 && <p className="text-sm text-muted-foreground">No open times on this day. Try another date.</p>}
            <div className="flex flex-wrap gap-2">
              {slots.map((s) => (
                <button
                  key={s.start}
                  type="button"
                  disabled={!s.available}
                  title={s.reason || ""}
                  onClick={() => setStart(s.start)}
                  className={cn(
                    "rounded-full border px-3.5 py-1.5 text-sm font-semibold transition-colors",
                    start === s.start ? "border-primary bg-primary text-primary-foreground" : "border-input bg-paper hover:bg-secondary",
                    !s.available && "cursor-not-allowed line-through opacity-40"
                  )}
                >
                  {fmtTime(s.start)}
                </button>
              ))}
            </div>
          </div>
          {showNotes && (
            <div className="grid gap-1.5">
              <Label htmlFor="notes">What will you discuss? *</Label>
              <Textarea id="notes" value={notes} onChange={(e) => setNotes(e.target.value)} maxLength={1000} rows={3} required />
            </div>
          )}
          {error && <Notice msg={{ type: "error", text: error }} />}
          <Button type="submit" disabled={busy}>{busy ? "Saving…" : confirmLabel}</Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
