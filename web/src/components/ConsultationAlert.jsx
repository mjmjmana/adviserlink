import { useEffect, useState } from "react";
import { BellRing, MapPin, Video } from "lucide-react";
import { toast } from "sonner";
import { acceptMeetingDetails, myBookings } from "@/api";
import { ringBookingAlarm, soundOn } from "@/components/Bell";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Notice } from "@/components/ui/alert";
import { addDays, fmtDateLong, fmtTime, parseYmd, ymd } from "@/lib/dates";

export default function ConsultationAlert({ user }) {
  const [booking, setBooking] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (user.role !== "student") return undefined;
    const isLeader = user.student_group_role !== "member";
    let active = true;
    let polling = false;

    async function poll() {
      if (polling) return;
      polling = true;
      try {
        const today = new Date();
        const rows = await myBookings(ymd(today), ymd(addDays(today, 1)));
        if (!active) return;
        const now = Date.now();
        const next = rows
          .filter((item) => (!isLeader || item.student_id === user.user_id) && item.status === "confirmed" && !item.leader_accepted)
          .map((item) => ({ ...item, startsAt: new Date(`${item.slot_date}T${item.start_time}`).getTime() }))
          .filter((item) => item.startsAt >= now && item.startsAt - now <= 10 * 60 * 1000)
          .sort((a, b) => a.startsAt - b.startsAt)[0] || null;
        setBooking(next);
      } catch (requestError) {
        console.error("Could not check for upcoming consultations.", requestError);
      } finally {
        polling = false;
      }
    }

    poll();
    const timer = setInterval(poll, 10000);
    return () => {
      active = false;
      clearInterval(timer);
    };
  }, [user.role, user.student_group_role, user.user_id]);

  useEffect(() => {
    if (!booking) return undefined;
    const startsAt = new Date(`${booking.slot_date}T${booking.start_time}`).getTime();
    let lastRing = 0;
    const alertSound = () => {
      if (!soundOn()) return;
      const now = Date.now();
      if (now - lastRing >= 60000) {
        ringBookingAlarm();
        lastRing = now;
      }
    };
    alertSound();
    const repeat = setInterval(alertSound, 10000);
    const startAlarm = setTimeout(() => {
      if (soundOn()) ringBookingAlarm();
    }, Math.max(0, startsAt - Date.now()));
    return () => {
      clearInterval(repeat);
      clearTimeout(startAlarm);
    };
  }, [booking && booking.booking_id]);

  async function accept() {
    if (!booking) return;
    setBusy(true);
    setError("");
    try {
      await acceptMeetingDetails(booking.booking_id);
      setBooking(null);
      toast.success("Meeting details accepted.");
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={Boolean(booking)} onOpenChange={() => {}}>
      {booking && (
        <DialogContent onEscapeKeyDown={(event) => event.preventDefault()} onPointerDownOutside={(event) => event.preventDefault()}>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><BellRing className="h-5 w-5 text-primary" /> Consultation reminder</DialogTitle>
            <DialogDescription>
              Your consultation with {booking.adviser_name} starts at {fmtTime(booking.start_time)} on {fmtDateLong(parseYmd(booking.slot_date))}.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-3 rounded-xl bg-muted/60 p-4">
            {booking.meeting_type
              ? <p className="flex items-center gap-2 font-semibold">
                {booking.meeting_type === "online" ? <Video className="h-4 w-4" /> : <MapPin className="h-4 w-4" />}
                {booking.meeting_type === "online" ? "Online consultation" : "In-person consultation"}
              </p>
              : <p className="text-sm font-semibold">Waiting for the adviser to set whether this meeting is online or in person.</p>}
            {booking.location && <p className="break-all text-sm text-muted-foreground">{booking.location}</p>}
            <p className="text-sm text-muted-foreground">Please accept the adviser’s meeting details before the consultation starts. Unaccepted bookings are cancelled at their start time.</p>
          </div>
          {error && <Notice msg={{ type: "error", text: error }} />}
          {user.student_group_role === "member"
            ? <p className="text-sm font-semibold text-muted-foreground">Waiting for the group leader to accept these meeting details.</p>
            : booking.meeting_type
              ? <Button onClick={accept} disabled={busy}>{busy ? "Accepting…" : "Accept meeting details"}</Button>
              : <p className="text-sm font-semibold text-muted-foreground">You can accept as soon as the adviser sets the meeting details.</p>}
        </DialogContent>
      )}
    </Dialog>
  );
}
