import { cva } from "class-variance-authority";
import { cn } from "@/lib/utils";

const alertVariants = cva("rounded-2xl px-4 py-3 text-sm font-medium", {
  variants: {
    variant: {
      default: "bg-secondary text-secondary-foreground",
      success: "bg-[hsl(135_40%_88%)] text-success",
      destructive: "bg-[hsl(10_70%_90%)] text-destructive",
    },
  },
  defaultVariants: { variant: "default" },
});

export function Alert({ className, variant, ...props }) {
  return <div role="alert" className={cn(alertVariants({ variant }), className)} {...props} />;
}

// Madaling gamitin: <Notice msg={{ type: "ok" | "error", text: "..." }} />
export function Notice({ msg, className }) {
  if (!msg || !msg.text) return null;
  return <Alert variant={msg.type === "error" ? "destructive" : "success"} className={className}>{msg.text}</Alert>;
}
