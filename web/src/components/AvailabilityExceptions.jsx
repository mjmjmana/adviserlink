import { useCallback, useEffect, useState } from "react";
import { Calendar, Loader2, Plus, Trash2, X } from "lucide-react";
import { getAvailabilityExceptions, addAvailabilityException, deleteAvailabilityException } from "@/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Textarea } from "@/components/ui/textarea";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import { format, parseISO } from "date-fns";

export function AvailabilityExceptions({ onChange }) {
  const [exceptions, setExceptions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    specific_date: "",
    start_time: "",
    end_time: "",
    reason: "",
    is_all_day: false,
  });
  const [error, setError] = useState("");
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [deleting, setDeleting] = useState(null);

  const load = useCallback(async () => {
    try {
      const data = await getAvailabilityExceptions();
      setExceptions(data);
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMsg({ type: "", text: "" });
    try {
      await addAvailabilityException(form);
      setMsg({ type: "ok", text: "Exception added." });
      setShowForm(false);
      setForm({ specific_date: "", start_time: "", end_time: "", reason: "", is_all_day: false });
      load();
      onChange?.();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!deleting) return;
    setLoading(true);
    try {
      await deleteAvailabilityException(deleting);
      setMsg({ type: "ok", text: "Exception removed." });
      setDeleting(null);
      load();
      onChange?.();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  };

  const formatTime = (time) => {
    if (!time) return "";
    const [h, m] = time.split(":");
    const hour = parseInt(h, 10);
    const ampm = hour >= 12 ? "PM" : "AM";
    const displayHour = hour % 12 || 12;
    return `${displayHour}:${m} ${ampm}`;
  };

  return (
    <div className="grid gap-4">
      <div className="flex items-center justify-between">
        <CardTitle className="text-lg">Availability Exceptions</CardTitle>
        <Button onClick={() => setShowForm(true)}><Plus className="h-4 w-4 mr-2" /> Block Date/Time</Button>
      </div>

      <Notice msg={msg} />

      {showForm && (
        <Card className="p-4 border-primary/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Block Date/Time</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3">
            <form onSubmit={handleSubmit} className="grid gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="exc-date">Date *</Label>
                <Popover>
                  <PopoverTrigger asChild>
                    <Input
                      id="exc-date"
                      type="text"
                      readOnly
                      value={form.specific_date ? format(parseISO(form.specific_date), "MMM d, yyyy") : ""}
                      placeholder="Pick a date"
                    />
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0" align="start">
                    <Calendar
                      mode="single"
                      selected={form.specific_date ? parseISO(form.specific_date) : undefined}
                      onSelect={(d) => setForm({ ...form, specific_date: d ? format(d, "yyyy-MM-dd") : "" })}
                      initialFocus
                    />
                  </PopoverContent>
                </Popover>
              </div>
              <div className="flex items-center gap-2">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_all_day}
                    onChange={(e) => setForm({ ...form, is_all_day: e.target.checked })}
                    className="h-4 w-4 accent-primary"
                  />
                  <span>All day</span>
                </label>
              </div>
              {!form.is_all_day && (
                <div className="grid gap-1.5 sm:grid-cols-2">
                  <div className="grid gap-1.5">
                    <Label htmlFor="exc-start">Start Time *</Label>
                    <Input id="exc-start" type="time" value={form.start_time} onChange={(e) => setForm({ ...form, start_time: e.target.value })} required />
                  </div>
                  <div className="grid gap-1.5">
                    <Label htmlFor="exc-end">End Time *</Label>
                    <Input id="exc-end" type="time" value={form.end_time} onChange={(e) => setForm({ ...form, end_time: e.target.value })} required />
                  </div>
                </div>
              )}
              <div className="grid gap-1.5">
                <Label htmlFor="exc-reason">Reason</Label>
                <Input id="exc-reason" value={form.reason} onChange={(e) => setForm({ ...form, reason: e.target.value })} placeholder="e.g. Faculty meeting, Holiday, etc." maxLength={255} />
              </div>
              <div className="flex gap-2">
                <Button type="submit" disabled={loading}>
                  {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : "Add Exception"}
                </Button>
                <Button type="button" variant="outline" onClick={() => { setShowForm(false); setForm({ specific_date: "", start_time: "", end_time: "", reason: "", is_all_day: false }); }}>
                  <X className="h-4 w-4 mr-1" /> Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {exceptions.length === 0 ? (
        <Card className="p-8 text-center border-dashed">
          <p className="text-muted-foreground">No exceptions set. Your regular availability applies on all dates.</p>
        </Card>
      ) : (
        <div className="grid gap-2">
          {exceptions.map((exc) => (
            <Card key={exc.exception_id} className="p-3 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="flex flex-col items-center justify-center p-2 rounded-lg bg-primary/10 text-primary">
                  <span className="font-bold text-lg">{format(parseISO(exc.specific_date), "MMM")}</span>
                  <span className="text-2xl font-extrabold">{format(parseISO(exc.specific_date), "d")}</span>
                </div>
                <div>
                  <p className="font-medium">{exc.is_all_day ? "All day" : `${formatTime(exc.start_time)} – ${formatTime(exc.end_time)}`}</p>
                  {exc.reason && <p className="text-sm text-muted-foreground">{exc.reason}</p>}
                </div>
              </div>
              <Button variant="ghost" size="icon" className="text-destructive" onClick={() => setDeleting(exc.exception_id)} aria-label="Delete">
                <Trash2 className="h-4 w-4" />
              </Button>
            </Card>
          ))}
        </div>
      )}

      {deleting && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle>Delete Exception</CardTitle>
              <CardDescription>Are you sure you want to remove this availability exception? This cannot be undone.</CardDescription>
            </CardHeader>
            <CardContent className="flex gap-2 justify-end">
              <Button variant="outline" onClick={() => setDeleting(null)}>Cancel</Button>
              <Button variant="destructive" onClick={handleDelete} disabled={loading}>
                {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : "Delete"}
              </Button>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}

export default AvailabilityExceptions;