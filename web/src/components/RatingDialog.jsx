import { useState } from "react";
import { Star } from "lucide-react";
import { rateBooking } from "@/api";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Notice } from "@/components/ui/alert";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

const WORDS = ["", "Poor", "Fair", "Good", "Very good", "Excellent"];

// Mabilis na rating: pumili ng bituin, may komento kung gusto
export default function RatingDialog({ bookingId, onClose, onDone }) {
  const [stars, setStars] = useState(0);
  const [hover, setHover] = useState(0);
  const [comment, setComment] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    if (!stars) { setError("Tap a star to rate."); return; }
    setBusy(true);
    try { await rateBooking(bookingId, { stars, comment }); onDone(); } catch (err) { setError(err.message); setBusy(false); }
  }
  const shown = hover || stars;
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>How was your consultation?</DialogTitle>
          <DialogDescription>Your feedback helps other students choose the right adviser.</DialogDescription>
        </DialogHeader>
        <form onSubmit={submit} className="grid gap-4">
          <div className="flex flex-col items-center gap-1">
            <div className="flex gap-1" onMouseLeave={() => setHover(0)}>
              {[1, 2, 3, 4, 5].map((n) => (
                <button key={n} type="button" aria-label={`${n} star${n > 1 ? "s" : ""}`} onMouseEnter={() => setHover(n)} onClick={() => setStars(n)} className="p-1">
                  <Star className={cn("h-9 w-9 transition-colors", n <= shown ? "fill-primary text-primary" : "text-card-foreground/30")} />
                </button>
              ))}
            </div>
            <span className="h-5 text-sm font-semibold text-muted-foreground">{WORDS[shown]}</span>
          </div>
          <Textarea value={comment} onChange={(e) => setComment(e.target.value)} rows={3} maxLength={500} placeholder="Add a comment (optional)" />
          {error && <Notice msg={{ type: "error", text: error }} />}
          <Button type="submit" disabled={busy}>{busy ? "Sending…" : "Send feedback"}</Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
