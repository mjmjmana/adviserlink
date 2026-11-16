import { ChevronLeft, ChevronRight } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { MONTHS, WEEKDAYS, addDays, sameDay, startOfWeek, ymd } from "@/lib/dates";

// Week view: 7 araw na pantay ang laki, may bilang ng consultation kada araw
export default function WeekStrip({ selected, onSelect, marks, activityDates = [], openDates = [] }) {
  const start = startOfWeek(selected);
  const days = Array.from({ length: 7 }, (_, i) => addDays(start, i));
  const end = days[6];
  const label = `${MONTHS[start.getMonth()].slice(0, 3)} ${start.getDate()} – ${MONTHS[end.getMonth()].slice(0, 3)} ${end.getDate()}`;
  return (
    <div className="grid gap-3">
      <div className="flex items-center justify-between">
        <Button variant="outline" size="icon" className="border-card-foreground/30" onClick={() => onSelect(addDays(selected, -7))} aria-label="Previous week"><ChevronLeft /></Button>
        <strong>{label}</strong>
        <Button variant="outline" size="icon" className="border-card-foreground/30" onClick={() => onSelect(addDays(selected, 7))} aria-label="Next week"><ChevronRight /></Button>
      </div>
      <div className="grid grid-cols-7 gap-1.5">
        {days.map((d, i) => {
          const n = marks[ymd(d)] || 0;
          const hasActivity = activityDates.includes(ymd(d));
          const hasOpenTime = openDates.includes(ymd(d));
          const sel = sameDay(d, selected);
          return (
            <button
              key={ymd(d)}
              type="button"
              onClick={() => onSelect(d)}
              className={cn(
                "flex flex-col items-center gap-1 rounded-2xl py-3 transition-colors",
                sel ? "bg-primary text-primary-foreground" : "bg-secondary hover:bg-secondary/70",
                sameDay(d, new Date()) && !sel && "ring-2 ring-card-foreground"
              )}
            >
              <span className="text-[11px] font-bold opacity-70">{WEEKDAYS[i]}</span>
              <span className="text-xl font-extrabold">{d.getDate()}</span>
              <span className="flex h-1.5 items-center gap-0.5">
                {hasOpenTime && <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />}
                {hasActivity && <span className="h-1.5 w-1.5 rounded-full bg-amber-500" />}
                {!hasOpenTime && !hasActivity && n > 0 && <span className={cn("h-1.5 w-1.5 rounded-full", sel ? "bg-primary-foreground" : "bg-primary")} />}
                {!hasOpenTime && !hasActivity && n === 0 && <span className="h-1.5 w-1.5 rounded-full bg-transparent" />}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
