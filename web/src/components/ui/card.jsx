import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * @typedef {Object} CardProps
 * @property {React.HTMLAttributes<HTMLDivElement>} [props]
 * @property {"default"|"elevated"|"outlined"|"glass"|"glassStrong"|"ghost"|"soft"|"brand"} [variant]
 * @property {"none"|"sm"|"md"|"lg"|"xl"} [padding]
 * @property {boolean} [hover]
 */

const Card = React.forwardRef(
  /** @param {CardProps & {className?: string, children?: React.ReactNode}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ className, variant = "default", padding = "md", hover, children, ...props }, ref) => {
    const variants = {
      default: "bg-card border border-border",
      elevated: "bg-card border border-border shadow-card",
      outlined: "bg-transparent border-2 border-border",
      glass: "bg-muted/30 border border-border/20 backdrop-blur-xl",
      glassStrong: "bg-muted/50 border border-border/30 backdrop-blur-2xl",
      ghost: "bg-transparent border-none",
      soft: "bg-muted/50 border border-border/40 backdrop-blur-sm",
      brand: "bg-gradient-to-br from-primary/5 via-primary/10 to-transparent border border-primary/20",
    };

    const paddings = {
      none: "",
      sm: "p-3",
      md: "p-5",
      lg: "p-6",
      xl: "p-8",
    };

    return (
      <div
        ref={ref}
        className={cn(
          "rounded-[var(--radius-card)] transition-all duration-300",
          variants[variant],
          paddings[padding],
          hover && "hover:shadow-[0_8px_30px_-8px_rgba(0,0,0,0.15)] hover:-translate-y-1 cursor-pointer hover:border-primary/30",
          className
        )}
        {...props}
      >
        {children}
      </div>
    );
  }
);
Card.displayName = "Card";

const CardHeader = React.forwardRef(
  /** @param {React.HTMLAttributes<HTMLDivElement> & {className?: string}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("flex flex-col space-y-1.5", className)} {...props} />
  )
);
CardHeader.displayName = "CardHeader";

const CardTitle = React.forwardRef(
  /** @param {React.HTMLAttributes<HTMLHeadingElement> & {className?: string}} props */
  /** @param {React.Ref<HTMLHeadingElement>} ref */
  ({ className, ...props }, ref) => (
    <h3 ref={ref} className={cn("text-lg font-semibold text-foreground tracking-tight leading-snug", className)} {...props} />
  )
);
CardTitle.displayName = "CardTitle";

const CardDescription = React.forwardRef(
  /** @param {React.HTMLAttributes<HTMLParagraphElement> & {className?: string}} props */
  /** @param {React.Ref<HTMLParagraphElement>} ref */
  ({ className, ...props }, ref) => (
    <p ref={ref} className={cn("text-sm text-muted-foreground leading-relaxed", className)} {...props} />
  )
);
CardDescription.displayName = "CardDescription";

const CardContent = React.forwardRef(
  /** @param {React.HTMLAttributes<HTMLDivElement> & {className?: string}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("pt-2", className)} {...props} />
  )
);
CardContent.displayName = "CardContent";

const CardFooter = React.forwardRef(
  /** @param {React.HTMLAttributes<HTMLDivElement> & {className?: string}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn("flex items-center mt-4 gap-3 pt-4 border-t border-border/50", className)}
      {...props}
    />
  )
);
CardFooter.displayName = "CardFooter";

export { Card, CardHeader, CardFooter, CardTitle, CardDescription, CardContent };