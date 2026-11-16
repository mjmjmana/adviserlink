import * as React from "react";
import { Slot, Slottable } from "@radix-ui/react-slot";
import { cva } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-2xl text-sm font-semibold transition-all duration-200 ease-out focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/30 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 active:scale-[0.98]",
  {
    variants: {
      variant: {
        default: "bg-primary text-primary-foreground hover:bg-primary/95 hover:shadow-[0_6px_20px_-6px_hsl(var(--primary)/.5)] hover:-translate-y-0.5",
        destructive: "bg-destructive text-destructive-foreground hover:bg-destructive/95 hover:shadow-[0_6px_20px_-6px_hsl(var(--destructive)/.5)] hover:-translate-y-0.5",
        outline: "border border-border bg-transparent hover:bg-muted hover:text-foreground hover:border-border/60",
        secondary: "bg-secondary text-secondary-foreground hover:bg-secondary/90 hover:-translate-y-0.5",
        ghost: "bg-transparent hover:bg-muted hover:text-foreground",
        link: "text-primary underline-offset-4 hover:underline",
        success: "bg-success text-success-foreground hover:bg-success/95 hover:shadow-[0_6px_20px_-6px_hsl(var(--success)/.5)] hover:-translate-y-0.5",
      },
      size: {
        default: "h-11 px-5 py-2 text-sm",
        sm: "h-9 rounded-xl px-4 text-xs",
        lg: "h-12 rounded-2xl px-6 text-base",
        xl: "h-14 rounded-2xl px-8 text-lg",
        icon: "h-11 w-11",
        iconSm: "h-9 w-9",
        iconLg: "h-12 w-12",
      },
      fullWidth: {
        true: "w-full",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);

/**
 * @typedef {Object} ButtonProps
 * @property {React.ButtonHTMLAttributes<HTMLButtonElement>} [props]
 * @property {keyof typeof buttonVariants.variants.variant} [variant]
 * @property {keyof typeof buttonVariants.variants.size} [size]
 * @property {boolean} [fullWidth]
 * @property {boolean} [asChild]
 * @property {boolean} [loading]
 * @property {React.ReactNode} [iconLeft]
 * @property {React.ReactNode} [iconRight]
 */

const Button = React.forwardRef(
  /** @param {ButtonProps & {className?: string, children?: React.ReactNode}} props */
  /** @param {React.Ref<HTMLButtonElement>} ref */
  ({ className, variant, size, fullWidth, asChild = false, loading = false, iconLeft, iconRight, disabled, children, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className, fullWidth }))}
        ref={ref}
        disabled={disabled || loading}
        aria-busy={loading}
        {...props}
      >
        {loading ? (
          <svg className="h-4 w-4 animate-spin" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
          </svg>
        ) : iconLeft ? (
          <span className="flex-shrink-0" aria-hidden="true">{iconLeft}</span>
        ) : null}
        <Slottable>{children}</Slottable>
        {!loading && iconRight && <span className="flex-shrink-0" aria-hidden="true">{iconRight}</span>}
      </Comp>
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };