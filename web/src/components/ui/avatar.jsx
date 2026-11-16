import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * @typedef {Object} AvatarProps
 * @property {React.HTMLAttributes<HTMLDivElement>} [props]
 * @property {string} [src]
 * @property {string} [alt]
 * @property {React.ReactNode} [fallback]
 * @property {"xs"|"sm"|"md"|"lg"|"xl"|"2xl"} [size]
 * @property {"circle"|"square"} [shape]
 * @property {"online"|"offline"|"busy"|"away"} [status]
 * @property {"bottom-right"|"top-right"|"bottom-left"|"top-left"} [statusPosition]
 */

const sizeClasses = {
  xs: "h-6 w-6 text-xs",
  sm: "h-8 w-8 text-sm",
  md: "h-10 w-10 text-base",
  lg: "h-12 w-12 text-lg",
  xl: "h-16 w-16 text-xl",
  "2xl": "h-24 w-24 text-2xl",
};

const statusSizes = {
  xs: "h-1.5 w-1.5",
  sm: "h-2 w-2",
  md: "h-2.5 w-2.5",
  lg: "h-3 w-3",
  xl: "h-4 w-4",
  "2xl": "h-5 w-5",
};

const statusColors = {
  online: "bg-success border-surface",
  offline: "bg-muted-foreground/50 border-surface",
  busy: "bg-destructive border-surface",
  away: "bg-warning border-surface",
};

const Avatar = React.forwardRef(
  /** @param {AvatarProps & {className?: string}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ className, src, alt, fallback, size = "md", shape = "circle", status, statusPosition = "bottom-right", ...props }, ref) => {
    const shapeClass = shape === "circle" ? "rounded-full" : "rounded-2xl";
    const statusPosClasses = {
      "bottom-right": "bottom-0 right-0",
      "top-right": "top-0 right-0",
      "bottom-left": "bottom-0 left-0",
      "top-left": "top-0 left-0",
    };

    return (
      <div ref={ref} className={cn("relative inline-flex shrink-0", sizeClasses[size], className)} {...props}>
        {src ? (
          <img src={src} alt={alt || "Avatar"} className={cn("h-full w-full object-cover", shapeClass)} />
        ) : (
          <div className={cn(
            "h-full w-full flex items-center justify-center font-semibold transition-colors",
            shapeClass,
            "bg-gradient-to-br from-primary/15 to-primary/5 text-primary"
          )}>
            {fallback || (alt ? alt.charAt(0).toUpperCase() : "?")}
          </div>
        )}
        {status && (
          <span
            className={cn(
              "absolute rounded-full border-2 shadow-sm",
              statusSizes[size],
              statusColors[status],
              statusPosClasses[statusPosition]
            )}
            aria-label={status}
          />
        )}
      </div>
    );
  }
);
Avatar.displayName = "Avatar";

/**
 * @typedef {Object} AvatarGroupProps
 * @property {React.HTMLAttributes<HTMLDivElement>} [props]
 * @property {number} [max]
 * @property {"xs"|"sm"|"md"|"lg"|"xl"|"2xl"} [size]
 * @property {number} [overlap]
 */

const AvatarGroup = React.forwardRef(
  /** @param {AvatarGroupProps & {className?: string, children?: React.ReactNode}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ className, max = 5, size = "md", overlap = 8, children, ...props }, ref) => {
    const childArray = React.Children.toArray(children).filter(React.isValidElement);
    const visibleChildren = childArray.slice(0, max);
    const remainingCount = childArray.length - max;

    return (
      <div ref={ref} className={cn("flex items-center", className)} {...props}>
        <div className="flex -space-x-2" role="group" aria-label={`${childArray.length} people`}>
          {visibleChildren.map((child, index) => (
            <span key={index} className={cn("relative z-10", index === 0 && "z-20")} style={{ zIndex: max - index }}>
              {React.cloneElement(child, { size })}
            </span>
          ))}
          {remainingCount > 0 && (
            <div
              className={cn(
                "flex items-center justify-center bg-muted text-muted-foreground font-medium border-2 border-surface",
                sizeClasses[size],
                "rounded-full"
              )}
              style={{ zIndex: 0 }}
              aria-label={`${remainingCount} more`}
            >
              +{remainingCount}
            </div>
          )}
        </div>
      </div>
    );
  }
);
AvatarGroup.displayName = "AvatarGroup";

export { Avatar, AvatarGroup };