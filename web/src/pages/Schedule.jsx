import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import { CalendarPlus, Clock, MapPin, Star, StickyNote, Zap } from "lucide-react";
import { acceptMeetingDetails, cancelBooking, completeBooking, createBooking, downloadIcs, getAvailability, getNextSlots, getSlots, myBookings, rescheduleBooking, setMeeting } from "@/api";
import AttentionPanel from "@/components/AttentionPanel";
import AvailabilityPanel from "@/components/AvailabilityPanel";
import BookingDialog from "@/components/BookingDialog";
import RatingDialog from "@/components/RatingDialog";
import WeekStrip from "@/components/WeekStrip";
import { StatusPill } from "@/components/ui/bento";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import { GlassCard, CardHeader, InfoRow, PersonChip, EmptyState } from "@/components/ui/bento";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Alert, Notice } from "@/components/ui/alert";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { addDays, firstName, fmtDateLong, fmtTime, monthGrid, parseYmd, startOfWeek, ymd } from "@/lib/dates";
import { NextActionHome } from "@/components/NextAction";

function onlineMeetingHref(location) {
  const value = location?.trim();
  if (!value || /\s/.test(value)) return null;
  const candidate = /^https?:\/\//i.test(value) ? value : `https://${value}`;
  try {
    const url = new URL(candidate);
    const hostname = url.hostname.replace(/\.$/, "");
    return ["http:", "https:"].includes(url.protocol) &&
      (hostname === "localhost" || hostname.includes(".") || hostname.includes(":")) &&
      !url.username && !url.password
      ? candidate
      : null;
  } catch {
    return null;
  }
}

// Ang adviser ang nagpapasya kung online o in-person ang consultation, at kung saan.
function MeetingDialog({ booking, onClose, onSaved }) {
  const [type, setType] = useState(booking.meeting_type || "in-person");
  const [location, setLocation] = useState(booking.location || "");
  const [error, setError] = useState("");
  async function save(e) {
    e.preventDefault();
    try {
      await setMeeting(booking.booking_id, { meeting_type: type, location });
      onSaved();
    } catch (err) { setError(err.message); }
  }
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Meeting details</DialogTitle>
          <DialogDescription>{booking.student_name} · {fmtDateLong(parseYmd(booking.slot_date))}, {fmtTime(booking.start_time)}</DialogDescription>
        </DialogHeader>
        <form onSubmit={save} className="grid gap-4">
          <Tabs value={type} onValueChange={setType}>
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="in-person"><span>In person</span></TabsTrigger>
              <TabsTrigger value="online"><span>Online</span></TabsTrigger>
            </TabsList>
          </Tabs>
          <div className="grid gap-1.5">
            <Label htmlFor="loc">{type === "online" ? "Meeting link" : "Room / place"}</Label>
            <Input id="loc" value={location} onChange={(e) => setLocation(e.target.value)} maxLength={255} placeholder={type === "online" ? "https://meet.google.com/... or meet.google.com/..." : "e.g. CCSICT Faculty Room"} />
            {type === "online" && <p className="text-xs text-muted-foreground">Paste the complete meeting URL. Links without https:// will be saved as secure links.</p>}
          </div>
          {error && <Notice msg={{ type: "error", text: error }} />}
          <Button type="submit">Save and notify student</Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function ReasonDialog({ title, description, label, required, action, onClose, onDone, extra }) {
  const [reason, setReason] = useState("");
  const [stage, setStage] = useState("");
  const [error, setError] = useState("");
  async function submit(e) {
    e.preventDefault();
    try { await action(reason, stage); onDone(); } catch (err) { setError(err.message); }
  }
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader><DialogTitle>{title}</DialogTitle><DialogDescription>{description}</DialogDescription></DialogHeader>
        <form onSubmit={submit} className="grid gap-4">
          {extra && (
            <div className="grid gap-1.5">
              <Label htmlFor="stage">Stage (optional)</Label>
              <Input id="stage" value={stage} onChange={(e) => setStage(e.target.value)} maxLength={100} placeholder="e.g. Chapter 1 draft" />
            </div>
          )}
          <div className="grid gap-1.5">
            <Label htmlFor="reason">{label}</Label>
            <Textarea id="reason" value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={500} required={required} />
          </div>
          {error && <Notice msg={{ type: "error", text: error }} />}
          <Button type="submit">Confirm</Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function QuickBookingDialog({ quickPick, adviser, onClose, onDone, onError }) {
  const [notes, setNotes] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    if (!notes.trim()) {
      setError("Please tell us what you will discuss.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      await createBooking({
        adviser_id: adviser.adviser_id,
        slot_date: quickPick.date,
        start_time: quickPick.start,
        notes: notes.trim(),
      });
      onDone(parseYmd(quickPick.date));
    } catch (err) {
      onError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Book {fmtDateLong(parseYmd(quickPick.date))} at {fmtTime(quickPick.start)}?</DialogTitle>
          <DialogDescription>With {adviser.name}. Your adviser will set if it is online or in person.</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4">
          <div className="grid gap-1.5">
            <Label htmlFor="quick-booking-notes">What will you discuss? *</Label>
            <Textarea
              id="quick-booking-notes"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              maxLength={1000}
              rows={3}
              required
            />
          </div>
          {error && <Notice msg={{ type: "error", text: error }} />}
          <Button type="submit" disabled={busy}>{busy ? "Booking…" : "Yes, book it"}</Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function googleUrl(b, who) {
  const day = b.slot_date.replaceAll("-", "");
  const t = (x) => x.replace(":", "") + "00";
  const params = new URLSearchParams({
    action: "TEMPLATE",
    text: `Consultation with ${who}`,
    dates: `${day}T${t(b.start_time)}/${day}T${t(b.end_time)}`,
    details: [b.meeting_type === "online" ? "Online" : b.meeting_type === "in-person" ? "In person" : "", b.topic_brief].filter(Boolean).join(". "),
    location: b.location || "",
  });
  return `https://calendar.google.com/calendar/render?${params}`;
}

function consultationProgress(b) {
  if (b.status === "completed") return "Completed";
  if (b.status === "cancelled") return "Cancelled";
  const startsAt = new Date(`${b.slot_date}T${b.start_time}`);
  const endsAt = new Date(`${b.slot_date}T${b.end_time}`);
  const now = new Date();
  if (now < startsAt) return "Not started";
  if (now < endsAt) return "Ongoing";
  return "Awaiting completion";
}

function EventCard({ b, isStudent, canManage, onMeeting, onAcceptMeeting, onCancel, onDone, onReschedule, onRate, onError }) {
  const cancelled = b.status === "cancelled";
  const who = isStudent ? b.adviser_name : b.student_name;
  const photo = isStudent ? b.adviser_profile_photo : b.student_profile_photo;
  const progress = consultationProgress(b);
  const meetingHref = b.status === "confirmed" && b.meeting_type === "online"
    ? onlineMeetingHref(b.location)
    : null;
  const statusTone = {
    "Not started": "info",
    Ongoing: "warning",
    "Awaiting completion": "warning",
    Completed: "success",
    Cancelled: "default",
  }[progress] || "default";

  return (
    <article className={"flex gap-3 rounded-[var(--radius-card)] bg-muted/50 p-3 " + (cancelled ? "opacity-60" : "")}>
      <div className="grid min-w-[84px] place-content-center rounded-xl bg-gradient-to-b from-primary to-primary/80 px-2 py-3 text-center text-primary-foreground">
        <b className="text-sm">{fmtTime(b.start_time)}</b>
        <small className="opacity-80">{fmtTime(b.end_time)}</small>
      </div>
      <div className="grid flex-1 content-start gap-1.5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <span className="flex items-center gap-2 font-semibold">
            {photo ? (
              <img src={photo} alt="" className="h-8 w-8 rounded-full object-cover" />
            ) : (
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/20 text-sm font-bold text-primary">{who?.charAt(0).toUpperCase() || "?"}</span>
            )}
            {who}
          </span>
          <div className="flex flex-wrap gap-1.5">
            <StatusPill tone={statusTone} showDot>{progress}</StatusPill>
            {b.status === "confirmed" && b.meeting_type && <StatusPill tone="info" leadingIcon={<span>📍</span>}>{b.meeting_type === "online" ? "Online" : "In person"}</StatusPill>}
            {b.status === "confirmed" && !b.meeting_type && <StatusPill tone="warning">Awaiting meeting details</StatusPill>}
            {b.status === "confirmed" && b.meeting_type && <StatusPill tone={b.leader_accepted ? "success" : "warning"}>{b.leader_accepted ? "Leader accepted" : "Awaiting leader acceptance"}</StatusPill>}
            {b.status === "completed" && b.rating && <StatusPill tone="success" leadingIcon={<Star className="h-3 w-3 fill-current" />}>★ {b.rating}</StatusPill>}
          </div>
        </div>
        <p className="line-clamp-2 text-sm text-muted-foreground">{b.topic_brief}</p>
        {meetingHref ? (
          <a
            href={meetingHref}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1 text-sm font-semibold text-primary hover:underline"
          >
            <MapPin className="h-3.5 w-3.5" /> Join online meeting
          </a>
        ) : b.location ? (
          <InfoRow icon={<MapPin className="h-3.5 w-3.5" />} label="Location" value={b.location} iconColor="muted" />
        ) : null}
        {b.notes && <InfoRow icon={<StickyNote className="h-3.5 w-3.5" />} label="Notes" value={b.notes} iconColor="muted" />}
        {cancelled && b.cancel_reason && <small className="text-muted-foreground">Reason: {b.cancel_reason}</small>}
        {b.status === "completed" && (b.stage_status || b.remarks) && (
          <div className="grid gap-0.5 rounded-xl border-l-4 border-primary bg-muted px-3 py-2 text-sm">
            <b className="text-xs uppercase tracking-wide text-muted-foreground">Consultation notes</b>
            {b.stage_status && <span><b>Stage:</b> {b.stage_status}</span>}
            {b.remarks && <span>{b.remarks}</span>}
          </div>
        )}
        {b.status === "confirmed" && (
          <div className="mt-1 flex flex-wrap gap-2">
            {!isStudent && <Button size="sm" onClick={() => onMeeting(b)}>{b.meeting_type ? "Edit meeting" : "Set online / in person"}</Button>}
            {!isStudent && <Button size="sm" variant="secondary" onClick={() => onDone(b)}>Mark completed</Button>}
            {isStudent && canManage && b.meeting_type && !b.leader_accepted && <Button size="sm" onClick={() => onAcceptMeeting(b)}>Accept meeting details</Button>}
            {canManage && isStudent && <Button size="sm" variant="secondary" onClick={() => onReschedule(b)}>Reschedule</Button>}
            {canManage && <Button size="sm" variant="ghost" className="text-destructive" onClick={() => onCancel(b)}>Cancel</Button>}
          </div>
        )}
        {b.status === "confirmed" && (
          <div className="flex flex-wrap gap-3 text-xs font-bold">
            <a className="flex items-center gap-1 text-primary hover:underline" href={googleUrl(b, who)} target="_blank" rel="noreferrer"><CalendarPlus className="h-3.5 w-3.5" /> Add to Google Calendar</a>
            <button type="button" className="text-muted-foreground hover:underline" onClick={() => downloadIcs(b.booking_id).catch((e) => onError(e.message))}>Download .ics</button>
          </div>
        )}
        {canManage && isStudent && b.status === "completed" && !b.rating && (
          <div className="mt-1"><Button size="sm" onClick={() => onRate(b.booking_id)}><Star className="h-3.5 w-3.5" /> Rate this consultation</Button></div>
        )}
      </div>
    </article>
  );
}

export default function Schedule() {
  const { user, status } = useOutletContext();
  const navigate = useNavigate();
  const isStudent = user.role === "student";
  const isGroupMember = isStudent && user.student_group_role === "member";
  const [view, setView] = useState("month");
  const [selected, setSelected] = useState(new Date());
  const [month, setMonth] = useState(new Date());
  const [bookings, setBookings] = useState([]);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [tick, setTick] = useState(0);
  const [booking, setBooking] = useState(false);
  const [bookingSlot, setBookingSlot] = useState(null);
  const [consultationsOpen, setConsultationsOpen] = useState(false);
  const [consultations, setConsultations] = useState([]);
  const [consultationsLoading, setConsultationsLoading] = useState(false);
  const [meeting, setMeetingFor] = useState(null);
  const [cancelFor, setCancelFor] = useState(null);
  const [doneFor, setDoneFor] = useState(null);
  const [moveFor, setMoveFor] = useState(null);
  const [rateFor, setRateFor] = useState(null);
  const [quick, setQuick] = useState([]);
  const [quickPick, setQuickPick] = useState(null);
  const [availabilityOpen, setAvailabilityOpen] = useState(false);
  const [availabilitySlots, setAvailabilitySlots] = useState([]);
  const [hasAvailability, setHasAvailability] = useState(Boolean(status.has_availability));

  const adviser = isStudent && status.application && status.application.status === "approved" ? { adviser_id: status.application.adviser_id, name: status.application.adviser_name } : null;
  const canBook = Boolean(adviser && !isGroupMember);

  useEffect(() => {
    if (canBook) getNextSlots(adviser.adviser_id, 6).then(setQuick).catch(() => setQuick([]));
    else setQuick([]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick, canBook, adviser && adviser.adviser_id]);

  const anchor = view === "month" ? month : selected;
  const load = useCallback(async () => {
    const grid = monthGrid(anchor);
    try {
      const start = ymd(grid[0]);
      const end = ymd(grid[41]);
      const [nextBookings, nextSlots] = await Promise.all([
        myBookings(start, end),
        isStudent
          ? adviser ? getSlots(adviser.adviser_id, start, end) : Promise.resolve([])
          : getSlots(user.user_id, start, end),
      ]);
      setBookings(nextBookings);
      setAvailabilitySlots(nextSlots);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [anchor.getFullYear(), anchor.getMonth(), adviser && adviser.adviser_id, isStudent, user.user_id]);
  useEffect(() => { load(); }, [load, tick]);
  useEffect(() => {
    const timer = setInterval(() => setTick((current) => current + 1), 15000);
    return () => clearInterval(timer);
  }, []);
  const reload = () => setTick((t) => t + 1);
  const refreshAvailability = () => {
    getAvailability()
      .then((items) => setHasAvailability(items.length > 0))
      .catch((e) => setMsg({ type: "error", text: e.message }));
    reload();
  };

  const active = useMemo(() => bookings.filter((b) => b.status !== "cancelled"), [bookings]);
  const marks = useMemo(() => {
    const m = {};
    active.filter((b) => b.status === "confirmed").forEach((b) => { m[b.slot_date] = (m[b.slot_date] || 0) + 1; });
    availabilitySlots.forEach((slot) => {
      if (slot.available) m[slot.date] = (m[slot.date] || 0) + 1;
    });
    return m;
  }, [active, availabilitySlots]);
  const bookedDateKeys = useMemo(
    () => new Set(bookings.filter((b) => b.status === "confirmed").map((b) => b.slot_date)),
    [bookings],
  );
  const newActivityDateKeys = useMemo(
    () => new Set(bookings.filter((b) => b.has_new_activity).map((b) => b.slot_date)),
    [bookings],
  );
  const openDateKeys = useMemo(
    () => new Set(availabilitySlots.filter((slot) => slot.available).map((slot) => slot.date)),
    [availabilitySlots],
  );
  const calendarModifiers = useMemo(() => ({
    newActivity: [...newActivityDateKeys].map(parseYmd),
    booked: [...bookedDateKeys].filter((date) => !newActivityDateKeys.has(date)).map(parseYmd),
    open: [...openDateKeys].map(parseYmd),
  }), [bookedDateKeys, newActivityDateKeys, openDateKeys]);
  const day = bookings.filter((b) => b.slot_date === ymd(selected));
  const dayOpenSlots = availabilitySlots.filter((slot) => slot.date === ymd(selected) && slot.available);
  const ws = ymd(startOfWeek(selected)), we = ymd(addDays(startOfWeek(selected), 6));
  const thisWeek = active.filter((b) => b.slot_date >= ws && b.slot_date <= we);

  const pick = (d) => { if (d) { setSelected(d); setMonth(d); } };
  const done = (text) => { setMsg({ type: "ok", text }); reload(); };
  const acceptMeeting = async (b) => {
    try {
      await acceptMeetingDetails(b.booking_id);
      setBookings((current) => current.map((item) => item.booking_id === b.booking_id ? { ...item, leader_accepted: 1 } : item));
      setConsultations((current) => current.map((item) => item.booking_id === b.booking_id ? { ...item, leader_accepted: 1 } : item));
      done("Meeting details accepted.");
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
  };
  const showConsultations = async () => {
    setConsultationsOpen(true);
    setConsultationsLoading(true);
    try {
      setConsultations(await myBookings());
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setConsultationsLoading(false);
    }
  };

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Hello, {firstName(user.name)}!</h1>
        <p className="text-foreground/70">{isStudent ? `Your consultations with ${adviser ? adviser.name : "your adviser"}` : "Review consultations, see open times, and manage your availability."}</p>
      </div>
      {!isStudent && !hasAvailability && (
        <Alert className="flex flex-wrap items-center justify-between gap-3">
          <span>You haven't set your open times yet, so students can't book you.</span>
          <Button size="sm" onClick={() => setAvailabilityOpen(true)}>Set open times</Button>
        </Alert>
      )}
      <Notice msg={msg} />
      {!isGroupMember && <AttentionPanel reloadKey={tick} onBook={() => setBooking(true)} onRate={setRateFor} onMessage={setMsg} />}
      {/* Next Action Smart Nudge */}
      {!isGroupMember && <NextActionHome
        userRole={user.role}
        status={status}
        notifications={[]}
        applications={[]}
        bookings={bookings}
        documents={[]}
        milestones={[]}
        navigate={navigate}
      />}
      {canBook && quick.length > 0 && (
        <GlassCard>
          <CardHeader icon={<Zap className="h-5 w-5" />} title="Quick book" description={`Next available with ${adviser.name}`} iconColor="primary" />
          <div className="flex flex-wrap gap-2 pt-1">
            {quick.map((q) => (
              <button key={q.date + q.start} type="button" onClick={() => setQuickPick(q)}
                className="rounded-full border border-input bg-muted px-4 py-2 text-sm font-bold transition-colors hover:border-primary hover:bg-primary hover:text-primary-foreground">
                {fmtDateLong(parseYmd(q.date))} · {fmtTime(q.start)}
              </button>
            ))}
          </div>
        </GlassCard>
      )}
      <div className="grid items-stretch gap-5 lg:grid-cols-2">
        <GlassCard>
          <div className="grid content-start gap-3 p-6">
            <Tabs value={view} onValueChange={setView}>
              <TabsList><TabsTrigger value="month"><span>Month</span></TabsTrigger><TabsTrigger value="week"><span>Week</span></TabsTrigger></TabsList>
              <TabsContent value="month">
                <Calendar
                  mode="single"
                  selected={selected}
                  onSelect={pick}
                  month={month}
                  onMonthChange={setMonth}
                  modifiers={calendarModifiers}
                  modifiersClassNames={{
                    booked: "font-extrabold after:absolute after:bottom-1.5 after:left-1/2 after:h-1.5 after:w-1.5 after:-translate-x-1/2 after:rounded-full after:bg-primary after:content-['']",
                    open: "before:absolute before:bottom-1.5 before:left-[38%] before:h-1.5 before:w-1.5 before:rounded-full before:bg-emerald-500 before:content-['']",
                    newActivity: "font-extrabold after:absolute after:bottom-1.5 after:left-1/2 after:h-1.5 after:w-1.5 after:-translate-x-1/2 after:rounded-full after:bg-amber-500 after:content-['']",
                  }}
                />
              </TabsContent>
              <TabsContent value="week" className="grid gap-4">
                <WeekStrip selected={selected} onSelect={pick} marks={marks} activityDates={[...newActivityDateKeys]} openDates={[...openDateKeys]} />
                <div className="grid gap-2">
                  <p className="text-sm font-bold">This week</p>
                  {thisWeek.length === 0 && <p className="text-sm text-muted-foreground">No consultations this week.</p>}
                  {thisWeek.map((b) => (
                    <button key={b.booking_id} type="button" onClick={() => pick(parseYmd(b.slot_date))} className="flex items-center justify-between gap-2 rounded-xl bg-muted px-3 py-2 text-left text-sm hover:bg-muted/70">
                      <span className="flex items-center gap-2"><Clock className="h-4 w-4" /> {fmtDateLong(parseYmd(b.slot_date))} · {fmtTime(b.start_time)}</span>
                      <span className="flex items-center gap-2 font-semibold">
                        {(isStudent ? b.adviser_profile_photo : b.student_profile_photo) ? (
                          <img src={isStudent ? b.adviser_profile_photo : b.student_profile_photo} alt="" className="h-7 w-7 rounded-full object-cover" />
                        ) : (
                          <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary/20 text-xs font-bold text-primary">
                            {(isStudent ? b.adviser_name : b.student_name)?.charAt(0).toUpperCase() || "?"}
                          </span>
                        )}
                        {isStudent ? b.adviser_name : b.student_name}
                      </span>
                    </button>
                  ))}
                </div>
              </TabsContent>
            </Tabs>
            <div className="flex flex-wrap gap-x-4 gap-y-2 px-1 text-xs text-muted-foreground" aria-label="Calendar legend">
              {(!isStudent || adviser) && <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-emerald-500" /> Open times</span>}
              <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-primary" /> Consultations</span>
              <span className="flex items-center gap-1.5"><span className="h-2 w-2 rounded-full bg-amber-500" /> New activity</span>
            </div>
          </div>
        </GlassCard>

        <GlassCard>
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <h3 className="text-xl font-semibold">{fmtDateLong(selected)}</h3>
            <div className="flex flex-wrap gap-2">
              {!isStudent && <Button onClick={() => setAvailabilityOpen(true)}>Manage availability</Button>}
              <Button variant="outline" onClick={showConsultations}>Check consultations</Button>
            </div>
          </div>
          <div className="grid content-start gap-3 p-6 pt-0">
            {(!isStudent || adviser) && (
              <section className="grid gap-2 rounded-xl border border-emerald-500/25 bg-emerald-500/5 p-3">
                <div className="flex items-center justify-between gap-2">
                  <h4 className="text-sm font-bold">Open times</h4>
                  <span className="text-xs text-muted-foreground">{dayOpenSlots.length} available</span>
                </div>
                {dayOpenSlots.length
                  ? <div className="flex flex-wrap gap-2">{dayOpenSlots.map((slot) => canBook
                    ? (
                      <button key={slot.start} type="button" onClick={() => { setBookingSlot(slot); setBooking(true); }} className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-700 transition-colors hover:bg-emerald-500/20 dark:text-emerald-300" title={`Book ${fmtTime(slot.start)}`}>
                        {fmtTime(slot.start)}–{fmtTime(slot.end)} · Book
                      </button>
                    )
                    : <span key={slot.start} className="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-700 dark:text-emerald-300">{fmtTime(slot.start)}–{fmtTime(slot.end)}</span>
                  )}</div>
                  : <p className="text-xs text-muted-foreground">No open times on this date. Booked times are reserved automatically.</p>}
              </section>
            )}
            {day.length === 0 && <p className="text-sm text-muted-foreground">No consultations on this day.</p>}
            {day.map((b) => (
              <EventCard key={b.booking_id} b={b} isStudent={isStudent} canManage={b.can_manage && !isGroupMember} onMeeting={setMeetingFor} onAcceptMeeting={acceptMeeting} onCancel={setCancelFor} onDone={setDoneFor} onReschedule={setMoveFor} onRate={setRateFor} onError={(text) => setMsg({ type: "error", text })} />
            ))}
          </div>
        </GlassCard>
      </div>

      {!isStudent && (
        <Dialog open={availabilityOpen} onOpenChange={setAvailabilityOpen}>
          <DialogContent className="max-w-2xl">
            <DialogHeader>
              <DialogTitle>Manage open times</DialogTitle>
              <DialogDescription>Students can book available 30-minute times. Bookings are confirmed automatically, and the selected time is removed from availability.</DialogDescription>
            </DialogHeader>
            <AvailabilityPanel onChange={refreshAvailability} />
          </DialogContent>
        </Dialog>
      )}

      <Dialog open={consultationsOpen} onOpenChange={setConsultationsOpen}>
        <DialogContent className="max-h-[85vh] max-w-3xl overflow-hidden">
          <DialogHeader>
            <DialogTitle>All consultations</DialogTitle>
            <DialogDescription>Review upcoming, ongoing, completed, and cancelled consultations.</DialogDescription>
          </DialogHeader>
          <div className="grid max-h-[60vh] gap-3 overflow-y-auto pr-1">
            {consultationsLoading && <p className="text-sm text-muted-foreground">Loading consultations…</p>}
            {!consultationsLoading && consultations.length === 0 && <p className="text-sm text-muted-foreground">No consultations yet.</p>}
            {!consultationsLoading && consultations.map((b) => (
              <EventCard key={b.booking_id} b={b} isStudent={isStudent} canManage={b.can_manage && !isGroupMember} onMeeting={setMeetingFor} onAcceptMeeting={acceptMeeting} onCancel={setCancelFor} onDone={setDoneFor} onReschedule={setMoveFor} onRate={setRateFor} onError={(text) => setMsg({ type: "error", text })} />
            ))}
          </div>
        </DialogContent>
      </Dialog>

      {canBook && (
        <BookingDialog
          adviser={adviser}
          open={booking}
          initialDate={bookingSlot ? parseYmd(bookingSlot.date) : undefined}
          initialStart={bookingSlot?.start}
          onOpenChange={(open) => { setBooking(open); if (!open) setBookingSlot(null); }}
          onSubmit={(date, start, notes) => createBooking({ adviser_id: adviser.adviser_id, slot_date: date, start_time: start, notes })}
          onDone={(d) => { setBooking(false); setBookingSlot(null); pick(d); done("Consultation booked. Your adviser was notified."); }}
        />
      )}
      {moveFor && (
        <BookingDialog
          adviser={{ adviser_id: moveFor.adviser_id, name: moveFor.adviser_name }}
          open
          onOpenChange={(o) => !o && setMoveFor(null)}
          title="Reschedule consultation"
          description={`Currently ${fmtDateLong(parseYmd(moveFor.slot_date))}, ${fmtTime(moveFor.start_time)}. Pick a new time and the other person will be notified.`}
          confirmLabel="Move consultation"
          showNotes={false}
          initialDate={parseYmd(moveFor.slot_date) < new Date() ? new Date() : parseYmd(moveFor.slot_date)}
          onSubmit={(date, start) => rescheduleBooking(moveFor.booking_id, { slot_date: date, start_time: start })}
          onDone={(d) => { setMoveFor(null); pick(d); done("Consultation moved. The other person was notified."); }}
        />
      )}
      {quickPick && canBook && adviser && (
        <QuickBookingDialog
          quickPick={quickPick}
          adviser={adviser}
          onClose={() => setQuickPick(null)}
          onDone={(d) => { setQuickPick(null); pick(d); done("Consultation booked. Your adviser was notified."); }}
          onError={(text) => { setQuickPick(null); setMsg({ type: "error", text }); reload(); }}
        />
      )}
      {rateFor && <RatingDialog bookingId={rateFor} onClose={() => setRateFor(null)} onDone={() => { setRateFor(null); done("Thanks for your feedback!"); }} />}
      {meeting && <MeetingDialog booking={meeting} onClose={() => setMeetingFor(null)} onSaved={() => { setMeetingFor(null); done("Meeting details saved. The student was notified."); }} />}
      {cancelFor && (
        <ReasonDialog
          title="Cancel this consultation?"
          description="The other person will be notified."
          label={isStudent ? "Reason (optional)" : "Reason for the student (required)"}
          required={!isStudent}
          action={(reason) => cancelBooking(cancelFor.booking_id, reason)}
          onClose={() => setCancelFor(null)}
          onDone={() => { setCancelFor(null); done("Consultation cancelled. The time is available to other advisees again."); }}
        />
      )}
      {doneFor && (
        <ReasonDialog
          title="Mark as completed"
          description="Optionally leave a short progress note."
          label="Remarks (optional)"
          extra
          action={(remarks, stage) => completeBooking(doneFor.booking_id, { stage_status: stage, remarks })}
          onClose={() => setDoneFor(null)}
          onDone={() => { setDoneFor(null); done("Marked as completed."); }}
        />
      )}
    </>
  );
}