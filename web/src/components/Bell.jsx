import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Bell as BellIcon } from "lucide-react";
import { toast } from "sonner";
import { getNotifications, readAllNotifications } from "@/api";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";

export const soundOn = () => localStorage.getItem("adviserlink_sound") !== "off";

let notificationAudio;
let bookingAlarmAudio;

export function ring() {
  try {
    notificationAudio ||= new Audio("/elegant-notification-sound.ogg");
    notificationAudio.currentTime = 0;
    notificationAudio.play().catch((error) => {
      console.warn("Could not play the notification sound.", error);
    });
  } catch (error) {
    console.warn("Could not play the notification sound.", error);
  }
}

export function ringBookingAlarm() {
  try {
    bookingAlarmAudio ||= new Audio("/booking-alarm.mp3");
    bookingAlarmAudio.currentTime = 0;
    bookingAlarmAudio.play().catch((error) => {
      console.warn("Could not play the booking alarm sound.", error);
    });
  } catch (error) {
    console.warn("Could not play the booking alarm sound.", error);
  }
}

export default function Bell({ onPoll }) {
  const navigate = useNavigate();
  const [data, setData] = useState({ items: [], unread: 0 });
  const [open, setOpen] = useState(false);
  const lastId = useRef(null);
  const burst = useRef(0); // ilang bagong notification ang nakapila sa kasalukuyang pop-up
  const openRef = useRef(false);

  async function poll() {
    try {
      const d = await getNotifications(8);
      const newest = d.items.length ? d.items[0].notification_id : 0;
      if (lastId.current !== null && newest > lastId.current && !openRef.current) {
        const fresh = d.items.filter((n) => n.notification_id > lastId.current && !n.is_read);
        if (fresh.length) {
          if (soundOn()) ring();
          burst.current += fresh.length;
          const n = burst.current;
          // Iisang pop-up lang: kapag may dagdag habang nakikita pa, pinapalitan ang laman ("3 new notifications")
          toast(n > 1 ? `${n} new notifications` : fresh[0].message, {
            id: "adviserlink-notif",
            duration: 5000,
            action: { label: "View", onClick: () => navigate(n > 1 ? "/notifications" : `/notifications?open=${fresh[0].notification_id}`) },
            onAutoClose: () => { burst.current = 0; },
            onDismiss: () => { burst.current = 0; },
          });
        }
      }
      lastId.current = newest;
      setData(d);
      document.title = d.unread ? `(${d.unread}) AdviserLink` : "AdviserLink";
      if (onPoll) onPoll();
    } catch {
      /* offline o hindi pa naka-login */
    }
  }

  useEffect(() => {
    poll();
    const t = setInterval(poll, 15000);
    return () => clearInterval(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function onOpenChange(next) {
    setOpen(next);
    openRef.current = next;
    if (next) { toast.dismiss("adviserlink-notif"); burst.current = 0; poll(); }
  }

  const go = (to) => { setOpen(false); openRef.current = false; navigate(to); };

  return (
    <Popover open={open} onOpenChange={onOpenChange}>
      <PopoverTrigger asChild>
        <button type="button" aria-label="Notifications" className="relative rounded-full p-2 text-foreground transition-colors hover:bg-muted">
          <BellIcon className="h-5 w-5" />
          {data.unread > 0 && (
            <span className="absolute -right-0.5 -top-0.5 min-w-[18px] rounded-full bg-primary px-1 text-center text-[10px] font-extrabold text-primary-foreground">{data.unread}</span>
          )}
        </button>
      </PopoverTrigger>
      <PopoverContent className="w-[min(22rem,calc(100vw-2rem))]">
        <div className="mb-2 flex items-center justify-between">
          <p className="font-bold">Notifications</p>
          {data.unread > 0 && (
            <button type="button" className="text-xs font-bold text-primary" onClick={async () => { await readAllNotifications().catch(() => {}); poll(); }}>Mark all read</button>
          )}
        </div>
        {data.items.length === 0 && <p className="text-sm text-muted-foreground">Nothing yet.</p>}
        <div className="grid max-h-[50vh] gap-2 overflow-y-auto">
          {data.items.slice(0, 5).map((n) => (
            <button key={n.notification_id} type="button" onClick={() => go(`/notifications?open=${n.notification_id}`)}
              className={cn("rounded-xl p-3 text-left text-sm transition-colors", n.is_read ? "bg-secondary hover:bg-secondary/70" : "bg-primary/25 hover:bg-primary/35")}>
              <span className="line-clamp-2">{n.message}</span>
              <small className="mt-1 block text-xs text-muted-foreground">{n.date_sent}</small>
            </button>
          ))}
        </div>
        <button type="button" onClick={() => go("/notifications")} className="mt-3 w-full rounded-full bg-background py-2 text-sm font-bold text-foreground hover:bg-background/85">
          View all notifications
        </button>
      </PopoverContent>
    </Popover>
  );
}
