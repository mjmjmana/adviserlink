import { cn } from "@/lib/utils";

export default function Logo({ size = 36, withName = false, className, nameClassName }) {
  return (
    <span className={cn("inline-flex items-center gap-2.5", className)}>
      <img
        src={`${import.meta.env.BASE_URL}adviserlink-logo.png`}
        width={size}
        height={size}
        alt={withName ? "" : "AdviserLink logo"}
        className="brand-mark shrink-0 object-contain"
      />
      {withName && (
        <span className={cn("brand-wordmark text-xl font-extrabold tracking-tight", nameClassName)}>
          adviser<span className="brand-word-accent">link</span>
        </span>
      )}
    </span>
  );
}
