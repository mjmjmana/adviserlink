import { cn } from "@/lib/utils";

export function Progress({ value = 0, className }) {
  return (
    <div className={cn("h-3 w-full overflow-hidden rounded-full bg-secondary", className)} role="progressbar" aria-valuenow={value} aria-valuemin={0} aria-valuemax={100}>
      <div className="h-full rounded-full bg-primary transition-all" style={{ width: `${value}%` }} />
    </div>
  );
}
