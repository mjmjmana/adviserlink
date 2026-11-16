import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * @typedef {Object} BadgeProps
 * @property {React.HTMLAttributes<HTMLSpanElement>} [props]
 * @property {"default"|"secondary"|"destructive"|"success"|"warning"|"info"|"outline"|"role-student"|"role-adviser"|"role-admin"} [variant]
 * @property {"sm"|"md"|"lg"} [size]
 * @property {boolean} [dot]
 * @property {React.ReactNode} [icon]
 */

const variantStyles = {
  default: "bg-primary/10 text-primary border border-primary/20",
  secondary: "bg-secondary text-secondary-foreground border border-border",
  destructive: "bg-destructive/10 text-destructive border border-destructive/20",
  success: "bg-success/10 text-success border border-success/20",
  warning: "bg-warning/10 text-warning border border-warning/20",
  info: "bg-info/10 text-info border border-info/20",
  outline: "bg-transparent text-foreground border border-border",
  "role-student": "bg-role-student/10 text-role-student border border-role-student/20",
  "role-adviser": "bg-role-adviser/10 text-role-adviser border border-role-adviser/20",
  "role-admin": "bg-role-admin/10 text-role-admin border border-role-admin/20",
};

const sizeStyles = {
  sm: "px-2.5 py-0.5 text-[11px] gap-1",
  md: "px-3 py-1 text-sm gap-1.5",
  lg: "px-4 py-1.5 text-base gap-2",
  pill: "px-4 py-1.5 text-sm gap-2 font-semibold",
};

const dotColors = {
  default: "bg-primary",
  secondary: "bg-muted-foreground",
  destructive: "bg-destructive",
  success: "bg-success",
  warning: "bg-warning",
  info: "bg-info",
  outline: "bg-border",
  "role-student": "bg-role-student",
  "role-adviser": "bg-role-adviser",
  "role-admin": "bg-role-admin",
};

const Badge = React.forwardRef(
  /** @param {{className?: string, variant?: keyof typeof variantStyles, size?: keyof typeof sizeStyles, dot?: boolean, icon?: React.ReactNode, children?: React.ReactNode}} props */
  /** @param {React.Ref<HTMLSpanElement>} ref */
  ({ className, variant = "default", size = "md", dot = false, icon, children, ...props }, ref) => {
    return (
      <span
        ref={ref}
        className={cn(
          "inline-flex items-center font-medium rounded-full border transition-all duration-200 whitespace-nowrap",
          variantStyles[variant],
          sizeStyles[size],
          className
        )}
        {...props}
      >
        {dot && <span className={cn("h-1.5 w-1.5 rounded-full flex-shrink-0", dotColors[variant])} aria-hidden="true" />}
        {icon && <span className="flex-shrink-0" aria-hidden="true">{icon}</span>}
        {children}
      </span>
    );
  }
);
Badge.displayName = "Badge";

/**
 * @typedef {Object} StatusBadgeProps
 * @property {Omit<BadgeProps, "variant">} [props]
 * @property {"pending"|"approved"|"declined"|"completed"|"cancelled"|"confirmed"|"in_progress"|"for_review"|"done"|"to_do"} status
 */

const statusVariantMap = {
  pending: "warning",
  approved: "success",
  declined: "destructive",
  completed: "success",
  cancelled: "destructive",
  confirmed: "info",
  in_progress: "info",
  for_review: "warning",
  done: "success",
  to_do: "secondary",
};

const statusLabelMap = {
  pending: "Pending",
  approved: "Approved",
  declined: "Declined",
  completed: "Completed",
  cancelled: "Cancelled",
  confirmed: "Confirmed",
  in_progress: "In Progress",
  for_review: "For Review",
  done: "Done",
  to_do: "To Do",
};

const StatusBadge = React.forwardRef(
  /** @param {{className?: string, status: keyof typeof statusVariantMap, children?: React.ReactNode, dot?: boolean}} props */
  /** @param {React.Ref<HTMLSpanElement>} ref */
  ({ className, status, children, dot = true, ...props }, ref) => {
    return (
      <Badge
        ref={ref}
        variant={statusVariantMap[status]}
        dot={dot}
        className={className}
        {...props}
      >
        {children || statusLabelMap[status]}
      </Badge>
    );
  }
);
StatusBadge.displayName = "StatusBadge";

/**
 * @typedef {Object} RoleBadgeProps
 * @property {Omit<BadgeProps, "variant">} [props]
 * @property {"student"|"adviser"|"admin"} role
 */

const RoleBadge = React.forwardRef(
  /** @param {{className?: string, role: "student"|"adviser"|"admin", children?: React.ReactNode, dot?: boolean}} props */
  /** @param {React.Ref<HTMLSpanElement>} ref */
  ({ className, role, children, dot = true, ...props }, ref) => {
    const variantMap = { student: "role-student", adviser: "role-adviser", admin: "role-admin" };
    const labelMap = { student: "Student", adviser: "Adviser", admin: "Admin" };
    return (
      <Badge
        ref={ref}
        variant={variantMap[role]}
        dot={dot}
        className={className}
        {...props}
      >
        {children || labelMap[role]}
      </Badge>
    );
  }
);
RoleBadge.displayName = "RoleBadge";

/**
 * @typedef {Object} CountBadgeProps
 * @property {Omit<BadgeProps, "variant"|"size">} [props]
 * @property {number} count
 * @property {number} [max]
 * @property {keyof typeof variantStyles} [variant]
 */

const CountBadge = React.forwardRef(
  /** @param {{className?: string, count: number, max?: number, variant?: keyof typeof variantStyles}} props */
  /** @param {React.Ref<HTMLSpanElement>} ref */
  ({ className, count, max = 99, variant = "default", ...props }, ref) => {
    if (count <= 0) return null;
    const displayCount = count > max ? `${max}+` : count;
    return (
      <Badge ref={ref} variant={variant} size="sm" className={cn("min-w-[1.25rem] justify-center", className)} {...props}>
        {displayCount}
      </Badge>
    );
  }
);
CountBadge.displayName = "CountBadge";

export { Badge, StatusBadge, RoleBadge, CountBadge };