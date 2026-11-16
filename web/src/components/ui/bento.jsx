import { cn } from "@/lib/utils";
import { forwardRef } from "react";

/**
 * @typedef {Object} GlassCardProps
 * @property {string} [className]
 * @property {"default"|"strong"|"soft"|"brand"} [variant="default"]
 * @property {"none"|"sm"|"md"|"lg"|"xl"} [padding="md"]
 * @property {boolean} [hover]
 * @property {React.ReactNode} [children]
 */

/**
 * GlassCard - Glassy card with gradient surface, thin border, backdrop-blur, 24px radius
 * Variants: default, strong, soft, brand
 */
export const GlassCard = forwardRef(
  /** @param {GlassCardProps & {ref?: React.Ref<HTMLDivElement>}} props */
  ({ className, variant = "default", padding = "md", hover, children, ...props }, ref) => {
    const variants = {
      default: "bg-muted/30 border border-border/20 backdrop-blur-xl",
      strong: "bg-muted/50 border border-border/30 backdrop-blur-2xl",
      soft: "bg-muted/50 border border-border/40 backdrop-blur-sm",
      brand: "bg-gradient-to-br from-primary/5 via-primary/10 to-transparent border border-primary/20 backdrop-blur-xl",
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
          "relative rounded-[var(--radius-card)] overflow-hidden transition-all duration-300",
          variants[variant],
          paddings[padding],
          hover && "hover:shadow-[0_8px_30px_-8px_rgb(0,0,0,0.15)] hover:-translate-y-1 hover:border-primary/30 cursor-pointer",
          className
        )}
        {...props}
      >
        {children}
      </div>
    );
  }
);

GlassCard.displayName = "GlassCard";

/**
 * @typedef {Object} CardHeaderProps
 * @property {string} [className]
 * @property {React.ReactNode} [icon]
 * @property {string} title
 * @property {string} [description]
 * @property {React.ReactNode} [actions]
 * @property {"primary"|"success"|"warning"|"error"|"info"|"student"|"adviser"|"admin"} [iconColor="primary"]
 */

/**
 * CardHeader - Icon chip + title + ghost action buttons
 */
export const CardHeader = forwardRef(
  /** @param {CardHeaderProps & {ref?: React.Ref<HTMLDivElement>}} props */
  ({ className, icon, title, description, actions, iconColor = "primary", ...props }, ref) => {
    return (
      <div ref={ref} className={cn("flex items-start justify-between gap-4 mb-4", className)} {...props}>
        <div className="flex items-start gap-3 min-w-0 flex-1">
          {icon && (
            <div
              className={cn(
                "shrink-0 flex h-10 w-10 items-center justify-center rounded-xl",
                iconColor === "primary" && "bg-primary/10 text-primary",
                iconColor === "success" && "bg-success/10 text-success",
                iconColor === "warning" && "bg-warning/10 text-warning",
                iconColor === "error" && "bg-error/10 text-error",
                iconColor === "info" && "bg-info/10 text-info",
                iconColor === "student" && "bg-role-student/10 text-role-student",
                iconColor === "adviser" && "bg-role-adviser/10 text-role-adviser",
                iconColor === "admin" && "bg-role-admin/10 text-role-admin",
              )}
            >
              {icon}
            </div>
          )}
          <div className="min-w-0">
            <h3 className="text-lg font-semibold text-foreground tracking-tight leading-snug truncate">{title}</h3>
            {description && <p className="mt-1 text-sm text-muted-foreground leading-relaxed">{description}</p>}
          </div>
        </div>
        {actions && <div className="flex items-center gap-1.5 shrink-0">{actions}</div>}
      </div>
    );
  }
);

CardHeader.displayName = "CardHeader";

/**
 * @typedef {Object} StatTileProps
 * @property {"orange"|"amber"|"coral"|"peach"|"blue"|"purple"|"green"|"rose"} [tone="orange"]
 * @property {React.ReactNode} icon
 * @property {string} label
 * @property {string|number} value
 * @property {string} [caption]
 * @property {string} [delta]
 * @property {() => void} [onExpand]
 * @property {string} [className]
 */

/**
 * StatTile - KPI tile with tinted gradient fill, icon circle, expand arrow, large number, caption with delta
 */
export function StatTile({
  tone = "orange",
  icon,
  label,
  value,
  caption,
  delta,
  onExpand,
  className,
}) {
  const toneClasses = {
    orange: "bg-gradient-to-br from-primary/5 via-primary/5 to-primary/10 border-primary/15 dark:from-primary/15 dark:via-primary/10 dark:to-primary/5 dark:border-primary/20",
    amber: "bg-gradient-to-br from-amber-50 via-amber-50 to-yellow-50 border-amber-200 dark:from-amber-900/20 dark:via-amber-900/10 dark:to-yellow-900/10 dark:border-amber-900/30",
    coral: "bg-gradient-to-br from-pink-50 via-pink-50 to-fuchsia-50 border-pink-200 dark:from-pink-900/20 dark:via-pink-900/10 dark:to-fuchsia-900/10 dark:border-pink-900/30",
    peach: "bg-gradient-to-br from-purple-50 via-violet-50 to-fuchsia-50 border-purple-200 dark:from-purple-900/20 dark:via-violet-900/10 dark:to-fuchsia-900/10 dark:border-purple-900/30",
    blue: "bg-gradient-to-br from-blue-50 via-blue-50 to-indigo-50 border-blue-200 dark:from-blue-900/20 dark:via-blue-900/10 dark:to-indigo-900/10 dark:border-blue-900/30",
    purple: "bg-gradient-to-br from-purple-50 via-purple-50 to-violet-50 border-purple-200 dark:from-purple-900/20 dark:via-purple-900/10 dark:to-violet-900/10 dark:border-purple-900/30",
    green: "bg-gradient-to-br from-green-50 via-green-50 to-emerald-50 border-green-200 dark:from-green-900/20 dark:via-green-900/10 dark:to-emerald-900/10 dark:border-green-900/30",
    rose: "bg-gradient-to-br from-rose-50 via-rose-50 to-pink-50 border-rose-200 dark:from-rose-900/20 dark:via-rose-900/10 dark:to-pink-900/10 dark:border-rose-900/30",
  };

  const iconColors = {
    orange: "text-primary bg-primary/10",
    amber: "text-amber-500 bg-amber-100 dark:text-amber-400 dark:bg-amber-900/30",
    coral: "text-pink-700 bg-pink-100 dark:text-pink-300 dark:bg-pink-900/30",
    peach: "text-purple-700 bg-purple-100 dark:text-purple-300 dark:bg-purple-900/30",
    blue: "text-blue-500 bg-blue-100 dark:text-blue-400 dark:bg-blue-900/30",
    purple: "text-purple-500 bg-purple-100 dark:text-purple-400 dark:bg-purple-900/30",
    green: "text-green-500 bg-green-100 dark:text-green-400 dark:bg-green-900/30",
    rose: "text-rose-500 bg-rose-100 dark:text-rose-400 dark:bg-rose-900/30",
  };

  return (
    <div
      className={cn(
        "relative rounded-[var(--radius-tile)] overflow-hidden p-6 transition-all duration-300",
        "border shadow-[0_4px_20px_-4px_rgba(0,0,0,0.1)]",
        toneClasses[tone],
        onExpand && "cursor-pointer hover:-translate-y-1 hover:shadow-[0_8px_30px_-8px_rgba(0,0,0,0.15)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring",
        className
      )}
      onClick={onExpand}
      onKeyDown={onExpand ? (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          onExpand();
        }
      } : undefined}
      role={onExpand ? "button" : undefined}
      tabIndex={onExpand ? 0 : undefined}
      aria-label={onExpand ? `View ${label} details` : undefined}
    >
      <div className="flex items-start justify-between">
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <div className={cn("shrink-0 flex h-10 w-10 items-center justify-center rounded-xl", iconColors[tone])}>
            {icon}
          </div>
          <div className="min-w-0 flex-1">
            <p className="break-words text-xs font-semibold leading-tight text-muted-foreground uppercase tracking-wide">{label}</p>
          </div>
        </div>
        {onExpand && (
          <span className="shrink-0 flex h-8 w-8 items-center justify-center rounded-full bg-background/50 text-muted-foreground transition-colors">
            <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
          </span>
        )}
      </div>
      <div className="mt-4">
        <div className="text-3xl sm:text-4xl font-extrabold tabular-nums text-foreground leading-none">{value}</div>
        {(caption || delta) && (
          <div className="mt-2 flex items-center gap-2 flex-wrap">
            {delta && (
              <span
                className={cn(
                  "text-sm font-bold",
                  delta.startsWith("+") || delta.startsWith("▲") ? "text-success" :
                  delta.startsWith("-") || delta.startsWith("▼") ? "text-error" : "text-muted-foreground"
                )}
              >
                {delta}
              </span>
            )}
            {caption && <span className="text-sm text-muted-foreground">{caption}</span>}
          </div>
        )}
      </div>
    </div>
  );
}

/**
 * @typedef {Object} IconButtonProps
 * @property {React.ReactNode} children
 * @property {"ghost"|"primary"|"destructive"|"outline"} [variant="ghost"]
 * @property {"sm"|"default"|"lg"} [size="default"]
 * @property {string} [className]
 */

/**
 * IconButton - Circular icon button (44px touch target)
 */
export const IconButton = forwardRef(
  /** @param {IconButtonProps & {ref?: React.Ref<HTMLButtonElement>}} props */
  ({ className, variant = "ghost", size = "default", children, ...props }, ref) => {
    const sizeClasses = {
      sm: "h-9 w-9",
      default: "h-11 w-11",
      lg: "h-12 w-12",
    };

    const variantClasses = {
      ghost: "bg-transparent hover:bg-muted text-foreground",
      primary: "bg-primary text-primary-foreground hover:bg-primary/90",
      destructive: "bg-transparent text-destructive hover:bg-destructive/10",
      outline: "border border-border bg-background hover:bg-muted",
    };

    return (
      <button
        ref={ref}
        className={cn(
          "inline-flex items-center justify-center rounded-full transition-colors",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
          "disabled:opacity-50 disabled:pointer-events-none",
          sizeClasses[size],
          variantClasses[variant],
          className
        )}
        {...props}
      >
        {children}
      </button>
    );
  }
);

IconButton.displayName = "IconButton";

/**
 * @typedef {Object} StatusPillProps
 * @property {React.ReactNode} children
 * @property {"primary"|"success"|"warning"|"error"|"info"|"student"|"adviser"|"admin"|"default"} [tone="primary"]
 * @property {boolean} [showDot=false]
 * @property {string} [className]
 * @property {React.ReactNode} [leadingIcon]
 */

/**
 * StatusPill - Fully rounded pill with leading dot, tinted background
 */
export function StatusPill({
  children,
  tone = "primary",
  showDot = false,
  className,
  leadingIcon,
}) {
  const toneClasses = {
    primary: "bg-primary/10 text-primary border-primary/20",
    success: "bg-success/10 text-success border-success/20",
    warning: "bg-warning/10 text-warning border-warning/20",
    error: "bg-error/10 text-error border-error/20",
    info: "bg-info/10 text-info border-info/20",
    student: "bg-role-student/10 text-role-student border-role-student/20",
    adviser: "bg-role-adviser/10 text-role-adviser border-role-adviser/20",
    admin: "bg-role-admin/10 text-role-admin border-role-admin/20",
    default: "bg-muted text-muted-foreground border-border/20",
  };

  const dotColors = {
    primary: "bg-primary",
    success: "bg-success",
    warning: "bg-warning",
    error: "bg-error",
    info: "bg-info",
    student: "bg-role-student",
    adviser: "bg-role-adviser",
    admin: "bg-role-admin",
    default: "bg-muted-foreground",
  };

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-semibold border transition-colors",
        toneClasses[tone],
        className
      )}
    >
      {showDot && <span className={cn("h-1.5 w-1.5 rounded-full", dotColors[tone])} />}
      {leadingIcon && <span className="h-3 w-3">{leadingIcon}</span>}
      {children}
    </span>
  );
}

/**
 * @typedef {Object} ProgressBarProps
 * @property {number} value
 * @property {number} [max=100]
 * @property {number} [segments=10]
 * @property {string} [label]
 * @property {string} [valueLabel]
 * @property {boolean} [showTicks=true]
 * @property {boolean} [showThumb=true]
 * @property {"primary"|"success"|"warning"|"error"|"info"} [color="primary"]
 * @property {string} [className]
 * @property {number} [rating]
 */

/**
 * ProgressBar - Thick rounded progress bar with round thumb, percentage ticks, star rating
 */
export function ProgressBar({
  value,
  max = 100,
  segments = 10,
  label,
  valueLabel,
  showTicks = true,
  showThumb = true,
  color = "primary",
  className,
  rating,
}) {
  const percentage = Math.min(Math.max((value / max) * 100, 0), 100);
  const colorClasses = {
    primary: "bg-primary",
    success: "bg-success",
    warning: "bg-warning",
    error: "bg-error",
    info: "bg-info",
  };

  return (
    <div className={cn("w-full", className)}>
      {(label || valueLabel) && (
        <div className="flex items-center justify-between mb-2">
          {label && <span className="text-sm font-semibold text-foreground">{label}</span>}
          {valueLabel && <span className={cn("text-sm font-bold", colorClasses[color])}>{valueLabel}</span>}
        </div>
      )}
      <div className="relative" style={{ height: 12 }}>
        {/* Track */}
        <div className="absolute inset-0 bg-muted rounded-full overflow-hidden" />
        {/* Fill */}
        <div
          className={cn("absolute top-0 left-0 h-full rounded-full transition-all duration-500", colorClasses[color])}
          style={{ width: `${percentage}%` }}
        />
        {/* Thumb */}
        {showThumb && (
          <div
            className="absolute top-1/2 -translate-y-1/2 w-5 h-5 bg-background border-3 rounded-full shadow-md transition-all duration-300"
            style={{
              left: `calc(${percentage}% - 10px)`,
              borderColor: `hsl(var(--${color}))`,
            }}
          />
        )}
      </div>
      {showTicks && (
        <div className="mt-2 flex justify-between">
          {Array.from({ length: segments + 1 }, (_, i) => {
            const pct = Math.round((i / segments) * 100);
            const isActive = pct <= percentage;
            return (
              <span
                key={i}
                className={cn(
                  "text-[10px] font-mono transition-colors",
                  isActive ? `text-${color}` : "text-muted-foreground"
                )}
              >
                {pct}%
              </span>
            );
          })}
        </div>
      )}
      {rating && (
        <div className="mt-2 flex items-center gap-1">
          {Array.from({ length: 5 }, (_, i) => (
            <span
              key={i}
              className={cn(
                "text-lg",
                i < Math.floor(rating) ? "text-amber-500" : "text-muted-foreground/30"
              )}
            >
              ★
            </span>
          ))}
          <span className="text-sm text-muted-foreground ml-1">{rating.toFixed(1)}</span>
        </div>
      )}
    </div>
  );
}

/**
 * @typedef {Object} ProgressBarWithTicksProps
 * @property {number} value
 * @property {number} [total=100]
 * @property {number} [completed=0]
 * @property {string} [label]
 * @property {string} [valueLabel]
 * @property {boolean} [showLabels=false]
 * @property {"primary"|"success"|"warning"|"error"|"info"} [color="primary"]
 * @property {string} [className]
 */

/**
 * ProgressBarWithTicks - Progress bar with percentage ticks and milestone markers
 */
export function ProgressBarWithTicks({
  value,
  total = 100,
  completed = 0,
  label,
  valueLabel,
  showLabels = false,
  color = "primary",
  className,
}) {
  const percentage = Math.min(Math.max((value / total) * 100, 0), 100);
  const colorClasses = {
    primary: "bg-primary",
    success: "bg-success",
    warning: "bg-warning",
    error: "bg-error",
    info: "bg-info",
  };

  return (
    <div className={cn("w-full", className)}>
      {(label || valueLabel) && (
        <div className="flex items-center justify-between mb-2">
          {label && <span className="text-sm font-semibold text-foreground">{label}</span>}
          {valueLabel && <span className={cn("text-sm font-bold", colorClasses[color])}>{valueLabel}</span>}
        </div>
      )}
      <div className="relative" style={{ height: 12 }}>
        {/* Track */}
        <div className="absolute inset-0 bg-muted rounded-full overflow-hidden" />
        {/* Fill */}
        <div
          className={cn("absolute top-0 left-0 h-full rounded-full transition-all duration-500", colorClasses[color])}
          style={{ width: `${percentage}%` }}
        />
        {/* Completed milestone markers */}
        {completed > 0 && Array.from({ length: completed }, (_, i) => (
          <div
            key={i}
            className="absolute top-1/2 -translate-y-1/2 w-3 h-3 bg-background border-2 rounded-full shadow-sm"
            style={{
              left: `calc(${(i + 1) / total * 100}% - 6px)`,
              borderColor: `hsl(var(--${color}))`,
            }}
          />
        ))}
      </div>
      {showLabels && (
        <div className="mt-2 flex justify-between text-[10px] font-mono text-muted-foreground">
          <span>0%</span>
          <span>25%</span>
          <span>50%</span>
          <span>75%</span>
          <span>100%</span>
        </div>
      )}
      <div className="mt-2 flex items-center gap-2 text-sm text-muted-foreground">
        <span>{completed} of {total} completed</span>
        {percentage === 100 && <span className="text-success font-bold">✓ Done</span>}
      </div>
    </div>
  );
}

/**
 * @typedef {Object} InfoRowProps
 * @property {React.ReactNode} icon
 * @property {string} label
 * @property {string|number} value
 * @property {"primary"|"success"|"warning"|"error"|"info"|"student"|"adviser"|"admin"|"muted"} [iconColor="primary"]
 * @property {() => void} [onEdit]
 * @property {string} [editAriaLabel="Edit"]
 * @property {string} [className]
 */

/**
 * InfoRow - Round icon, tiny muted label, medium value, circular edit button
 */
export function InfoRow({
  icon,
  label,
  value,
  iconColor = "primary",
  onEdit,
  editAriaLabel = "Edit",
  className,
}) {
  const iconColorClasses = {
    primary: "bg-primary/10 text-primary",
    success: "bg-success/10 text-success",
    warning: "bg-warning/10 text-warning",
    error: "bg-error/10 text-error",
    info: "bg-info/10 text-info",
    student: "bg-role-student/10 text-role-student",
    adviser: "bg-role-adviser/10 text-role-adviser",
    admin: "bg-role-admin/10 text-role-admin",
    muted: "bg-muted text-muted-foreground",
  };

  return (
    <div className={cn("flex items-center gap-3", className)}>
      <div className={cn("shrink-0 flex h-10 w-10 items-center justify-center rounded-full", iconColorClasses[iconColor])}>
        {icon}
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-xs font-medium text-muted-foreground truncate">{label}</p>
        <p className="text-base font-semibold text-foreground truncate">{value}</p>
      </div>
      {onEdit && (
        <button
          type="button"
          className="shrink-0 flex h-9 w-9 items-center justify-center rounded-full bg-muted/50 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
          onClick={onEdit}
          aria-label={editAriaLabel}
        >
          <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
        </button>
      )}
    </div>
  );
}

/**
 * @typedef {Object} PersonChipProps
 * @property {string} [avatar]
 * @property {string} name
 * @property {string} subtitle
 * @property {string} [stat]
 * @property {"primary"|"success"|"warning"|"error"|"info"|"student"|"adviser"|"admin"|"default"} [statTone="primary"]
 * @property {string} [className]
 * @property {() => void} [onClick]
 */

/**
 * PersonChip - Avatar, name, subtitle, stat pill
 */
export function PersonChip({
  avatar,
  name,
  subtitle,
  stat,
  statTone = "primary",
  className,
  onClick,
}) {
  return (
    <button
      type="button"
      className={cn(
        "inline-flex items-center gap-3 rounded-full bg-muted/50 px-3 py-1.5 border border-border/20 backdrop-blur-sm",
        "hover:bg-muted/70 transition-colors",
        onClick && "cursor-pointer",
        className
      )}
      onClick={onClick}
    >
      <div className="relative h-8 w-8 shrink-0">
        {avatar ? (
          <img src={avatar} alt="" className="h-8 w-8 rounded-full object-cover ring-2 ring-background" />
        ) : (
          <div className="h-8 w-8 rounded-full bg-primary/20 flex items-center justify-center">
            <span className="text-sm font-bold text-primary">{name.charAt(0).toUpperCase()}</span>
          </div>
        )}
      </div>
      <div className="min-w-0">
        <p className="font-medium truncate text-foreground">{name}</p>
        <p className="text-xs text-muted-foreground truncate">{subtitle}</p>
      </div>
      {stat && (
        <StatusPill tone={statTone} className="ml-2 shrink-0">
          {stat}
        </StatusPill>
      )}
    </button>
  );
}

/**
 * @typedef {Object} EmptyStateProps
 * @property {React.ReactNode} icon
 * @property {string} title
 * @property {string} description
 * @property {() => void} [action]
 * @property {string} [actionLabel]
 * @property {string} [className]
 */

/**
 * EmptyState - Centered illustration, message, single action
 */
export function EmptyState({
  icon,
  title,
  description,
  action,
  actionLabel,
  className,
}) {
  return (
    <div className={cn("flex flex-col items-center justify-center gap-4 rounded-[var(--radius-card)] p-8 text-center text-muted-foreground", className)}>
      <div className="h-12 w-12 opacity-40 flex items-center justify-center">
        {icon}
      </div>
      <p className="text-lg font-semibold text-foreground">{title}</p>
      <p className="text-sm max-w-xs">{description}</p>
      {action && actionLabel && (
        <button type="button" className="mt-2 rounded-full bg-primary px-5 py-2 text-sm font-bold text-primary-foreground hover:bg-primary/90 transition-colors" onClick={action}>
          {actionLabel}
        </button>
      )}
    </div>
  );
}