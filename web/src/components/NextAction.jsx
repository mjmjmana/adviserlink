import * as React from "react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar } from "@/components/ui/avatar";

export const NextActionType = {
  pendingApplication: "pendingApplication",
  upcomingBooking: "upcomingBooking",
  unreadNotification: "unreadNotification",
  documentRequired: "documentRequired",
  milestoneDue: "milestoneDue",
  ratingPending: "ratingPending",
  adviserApproval: "adviserApproval",
  scheduleAvailability: "scheduleAvailability",
  waitlistOpened: "waitlistOpened",
  none: "none",
};

// Inline icon components (defined first so iconMap can reference them)
function SearchIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <circle cx="11" cy="11" r="8" />
      <line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  );
}

function UserPlusIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <line x1="19" y1="8" x2="19" y2="14" />
      <line x1="22" y1="11" x2="16" y2="11" />
    </svg>
  );
}

function CheckCircleIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
      <polyline points="22 4 12 14.01 9 11.01" />
    </svg>
  );
}

function AlertCircleIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <circle cx="12" cy="12" r="10" />
      <line x1="12" y1="8" x2="12" y2="12" />
      <line x1="12" y1="16" x2="12.01" y2="16" />
    </svg>
  );
}

function CalendarIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
      <line x1="16" y1="2" x2="16" y2="6" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  );
}

function BellIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

function UploadIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="17 8 12 3 7 8" />
      <line x1="12" y1="3" x2="12" y2="15" />
    </svg>
  );
}

function AlertTriangleIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
      <line x1="12" y1="9" x2="12" y2="13" />
      <line x1="12" y1="17" x2="12.01" y2="17" />
    </svg>
  );
}

function StarIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
    </svg>
  );
}

function UserCheckIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <polyline points="17 11 19 13 22 10" />
    </svg>
  );
}

function ClockIcon({ className, ...props }) {
  return (
    <svg className={className} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" {...props}>
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </svg>
  );
}

const iconMap = {
  [NextActionType.pendingApplication]: UserPlusIcon,
  [NextActionType.upcomingBooking]: CalendarIcon,
  [NextActionType.unreadNotification]: BellIcon,
  [NextActionType.documentRequired]: UploadIcon,
  [NextActionType.milestoneDue]: AlertTriangleIcon,
  [NextActionType.ratingPending]: StarIcon,
  [NextActionType.adviserApproval]: UserCheckIcon,
  [NextActionType.scheduleAvailability]: ClockIcon,
  [NextActionType.waitlistOpened]: BellIcon,
};

const iconBgColors = {
  [NextActionType.pendingApplication]: "bg-brand-orange/10",
  [NextActionType.upcomingBooking]: "bg-brand-blue/10",
  [NextActionType.unreadNotification]: "bg-brand-amber/10",
  [NextActionType.documentRequired]: "bg-brand-amber/10",
  [NextActionType.milestoneDue]: "bg-brand-red/10",
  [NextActionType.ratingPending]: "bg-brand-green/10",
  [NextActionType.adviserApproval]: "bg-brand-orange/10",
  [NextActionType.scheduleAvailability]: "bg-brand-blue/10",
  [NextActionType.waitlistOpened]: "bg-brand-green/10",
};

const iconColors = {
  [NextActionType.pendingApplication]: "text-brand-orange",
  [NextActionType.upcomingBooking]: "text-brand-blue",
  [NextActionType.unreadNotification]: "text-brand-amber",
  [NextActionType.documentRequired]: "text-brand-amber",
  [NextActionType.milestoneDue]: "text-brand-red",
  [NextActionType.ratingPending]: "text-brand-green",
  [NextActionType.adviserApproval]: "text-brand-orange",
  [NextActionType.scheduleAvailability]: "text-brand-blue",
  [NextActionType.waitlistOpened]: "text-brand-green",
};

const badgeVariants = {
  [NextActionType.pendingApplication]: "default",
  [NextActionType.upcomingBooking]: "info",
  [NextActionType.unreadNotification]: "warning",
  [NextActionType.documentRequired]: "warning",
  [NextActionType.milestoneDue]: "destructive",
  [NextActionType.ratingPending]: "success",
  [NextActionType.adviserApproval]: "default",
  [NextActionType.scheduleAvailability]: "info",
  [NextActionType.waitlistOpened]: "success",
};

/**
 * @typedef {Object} NextAction
 * @property {string} type
 * @property {number} priority
 * @property {string} title
 * @property {string} description
 * @property {string} [route]
 * @property {() => void} [onTap]
 * @property {BadgeVariant} badgeVariant
 * @property {string} [badgeLabel]
 * @property {Record<string, unknown>} metadata
 */

/**
 * @typedef {Object} NextActionEngineOptions
 * @property {string} userRole
 * @property {Record<string, unknown> | null} status
 * @property {Array<Record<string, unknown>>} notifications
 * @property {Array<Record<string, unknown>>} applications
 * @property {Array<Record<string, unknown>>} bookings
 * @property {Array<Record<string, unknown>>} documents
 * @property {Array<Record<string, unknown>>} milestones
 * @property {(route: string) => void} navigate
 */

/**
 * Generate next actions based on user data
 * @param {NextActionEngineOptions} options
 * @returns {NextAction[]}
 */
export function generateNextActions({
  userRole,
  status,
  notifications,
  applications,
  bookings,
  documents,
  milestones,
  navigate,
}) {
  const acts = [];
  const now = new Date();
  const in30Min = new Date(now.getTime() + 30 * 60 * 1000);
  const in24Hours = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  const in7Days = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  // 1. Unread urgent notifications
  const unreadUrgent = notifications.filter((n) =>
    !n.is_read &&
    ["booking_confirmed", "application_approved", "booking_cancelled"].includes(n.type)
  );

  if (unreadUrgent.length > 0) {
    acts.push({
      type: NextActionType.unreadNotification,
      priority: 100,
      title: unreadUrgent.length === 1 ? "New notification" : `${unreadUrgent.length} new notifications`,
      description: unreadUrgent[0].message || "Check your notifications",
      route: "/notifications",
      badgeVariant: "warning",
      badgeLabel: unreadUrgent.length > 1 ? String(unreadUrgent.length) : null,
      onTap: () => navigate("/notifications"),
      metadata: {},
    });
  }

  // 2. Upcoming booking in 30 min
  const upcomingBooking = bookings.find((b) => {
    if (b.status !== "confirmed") return false;
    const start = new Date(`${b.booking_date}T${b.start_time}`);
    return start > now && start < in30Min;
  });

  if (upcomingBooking) {
    const start = new Date(`${upcomingBooking.booking_date}T${upcomingBooking.start_time}`);
    const mins = Math.round((start - now) / 60000);
    acts.push({
      type: NextActionType.upcomingBooking,
      priority: 95,
      title: "Consultation starting soon",
      description: `${upcomingBooking.adviser_name} in ${mins} min (${upcomingBooking.mode === "online" ? "Online" : "In-person"})`,
      onTap: () => navigate(`/schedule?booking=${upcomingBooking.booking_id}`),
      badgeVariant: "info",
      badgeLabel: `${mins}m`,
      metadata: { bookingId: upcomingBooking.booking_id },
    });
  }

  // 3. Pending application
  if (userRole === "adviser") {
    const pendingApps = applications.filter((a) => a.status === "pending");
    if (pendingApps.length > 0) {
      acts.push({
        type: NextActionType.pendingApplication,
        priority: 90,
        title: pendingApps.length === 1 ? "Application to review" : `${pendingApps.length} applications pending`,
        description: pendingApps[0].student_name ? `From ${pendingApps[0].student_name}` : "Review student requests",
        route: "/applications",
        badgeVariant: "default",
        badgeLabel: pendingApps.length > 1 ? String(pendingApps.length) : null,
        onTap: () => navigate("/applications"),
        metadata: {},
      });
    }
  } else if (userRole === "student") {
    const userId = status?.user_id;
    const myPending = applications.filter((a) => a.student_id === userId && a.status === "pending");
    if (myPending.length > 0) {
      acts.push({
        type: NextActionType.pendingApplication,
        priority: 85,
        title: "Application submitted",
        description: `Waiting for ${myPending[0].adviser_name || "adviser"} to respond`,
        route: "/advisers",
        badgeVariant: "info",
        onTap: () => navigate("/advisers"),
        metadata: {},
      });
    }
  }

  // 4. Adviser approval (admin)
  if (userRole === "admin" && (status?.pending_advisers || 0) > 0) {
    const count = status.pending_advisers;
    acts.push({
      type: NextActionType.adviserApproval,
      priority: 88,
      title: "Adviser awaiting approval",
      description: `${count} adviser${count > 1 ? "s" : ""} pending review`,
      route: "/adviser-approvals",
      badgeVariant: "default",
      badgeLabel: String(count),
      onTap: () => navigate("/adviser-approvals"),
      metadata: {},
    });
  }

  // 5. Document required for upcoming booking
  const confirmedBookings = bookings.filter((b) => {
    if (b.status !== "confirmed") return false;
    const start = new Date(`${b.booking_date}T${b.start_time}`);
    return start > now && start < in24Hours;
  });

  const docsNeeded = confirmedBookings.filter((b) =>
    !documents.some((d) => d.booking_id === b.booking_id && d.category === "draft")
  );

  if (docsNeeded.length > 0 && userRole === "student") {
    acts.push({
      type: NextActionType.documentRequired,
      priority: 80,
      title: "Upload draft before consultation",
      description: `${docsNeeded.length} booking${docsNeeded.length > 1 ? "s" : ""} in 24h need draft upload`,
      route: "/schedule",
      badgeVariant: "warning",
      badgeLabel: String(docsNeeded.length),
      onTap: () => navigate("/schedule"),
      metadata: {},
    });
  }

  // 6. Milestone due soon
  const dueMilestones = milestones.filter((m) => {
    if (["completed", "cancelled"].includes(m.status)) return false;
    const due = new Date(m.due_date);
    return due > now && due < in7Days;
  });

  if (dueMilestones.length > 0) {
    dueMilestones.sort((a, b) => new Date(a.due_date) - new Date(b.due_date));
    const nearest = dueMilestones[0];
    const days = Math.ceil((new Date(nearest.due_date) - now) / (1000 * 60 * 60 * 24));
    acts.push({
      type: NextActionType.milestoneDue,
      priority: 75,
      title: "Milestone deadline approaching",
      description: `${nearest.title} due in ${days} day${days > 1 ? "s" : ""}`,
      route: "/milestones",
      badgeVariant: days <= 2 ? "destructive" : "warning",
      badgeLabel: `${days}d`,
      onTap: () => navigate("/milestones"),
      metadata: {},
    });
  }

  // 7. Rating pending
  const completedNoRating = bookings.filter((b) => b.status === "completed" && !b.rating);
  if (completedNoRating.length > 0 && userRole === "student") {
    acts.push({
      type: NextActionType.ratingPending,
      priority: 60,
      title: "Rate your consultation",
      description: `${completedNoRating.length} completed session${completedNoRating.length > 1 ? "s" : ""} awaiting feedback`,
      route: "/schedule",
      badgeVariant: "success",
      badgeLabel: String(completedNoRating.length),
      onTap: () => navigate("/schedule"),
      metadata: {},
    });
  }

  // 8. Schedule availability (adviser with no slots)
  if (userRole === "adviser" && (status?.advisee_count || 0) > 0) {
    const hasAvailability = Boolean(status?.has_availability);
    if (!hasAvailability) {
      acts.push({
        type: NextActionType.scheduleAvailability,
        priority: 70,
        title: "Set your availability",
        description: "You have advisees but no available slots set",
        route: "/settings",
        badgeVariant: "info",
        onTap: () => navigate("/settings"),
        metadata: {},
      });
    }
  }

  // 9. Waitlist opened
  if (userRole === "student" && notifications.some((n) => !n.is_read && n.type === "waitlist_opened")) {
    acts.push({
      type: NextActionType.waitlistOpened,
      priority: 82,
      title: "Slot opened from waitlist",
      description: "A spot opened for an adviser you waitlisted",
      route: "/advisers",
      badgeVariant: "success",
      onTap: () => navigate("/advisers"),
      metadata: {},
    });
  }

  // Sort by priority (highest first)
  acts.sort((a, b) => b.priority - a.priority);
  return acts;
}

/**
 * @typedef {Object} NextActionNudgeProps
 * @property {string} userRole
 * @property {Record<string, unknown> | null} status
 * @property {Array<Record<string, unknown>>} notifications
 * @property {Array<Record<string, unknown>>} applications
 * @property {Array<Record<string, unknown>>} bookings
 * @property {Array<Record<string, unknown>>} documents
 * @property {Array<Record<string, unknown>>} milestones
 * @property {(route: string) => void} navigate
 * @property {string} [className]
 */

const PrimaryActionCard = React.forwardRef(
  /** @param {{action: NextAction, navigate: (route: string) => void, className?: string}} props */
  /** @param {React.Ref<HTMLDivElement>} ref */
  ({ action, navigate, className }, ref) => {
    const IconComponent = iconMap[action.type] || "AlertCircle";
    const bgColor = iconBgColors[action.type] || "bg-muted";
    const color = iconColors[action.type] || "text-muted-foreground";

    return (
      <Card
        ref={ref}
        variant="elevated"
        padding="lg"
        hover
        onClick={action.onTap || (action.route ? () => navigate(action.route) : undefined)}
        className={cn("cursor-pointer", className)}
      >
        <div className="flex gap-4">
          <div className={cn("flex-shrink-0 w-12 h-12 rounded-2xl items-center justify-center", bgColor)}>
            <IconComponent className={cn("h-6 w-6", color)} aria-hidden="true" />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between gap-2">
              <h3 className="text-lg font-bold text-foreground truncate">{action.title}</h3>
              {action.badgeLabel && (
                <Badge variant={action.badgeVariant} size="sm">{action.badgeLabel}</Badge>
              )}
            </div>
            <p className="mt-1 text-sm text-muted-foreground">{action.description}</p>
            {(action.onTap || action.route) && (
              <Button
                className="mt-4"
                size="sm"
                onClick={action.onTap || (() => { if (action.route) navigate(action.route); })}
              >
                Take Action
              </Button>
            )}
          </div>
        </div>
      </Card>
    );
  }
);
PrimaryActionCard.displayName = "PrimaryActionCard";

const SecondaryActionCard = ({ action, navigate }) => {
  const IconComponent = iconMap[action.type] || "AlertCircle";
  const bgColor = iconBgColors[action.type] || "bg-muted";
  const color = iconColors[action.type] || "text-muted-foreground";

  return (
    <Card
      variant="outlined"
      padding="md"
      hover
      onClick={action.onTap || (action.route ? () => navigate(action.route) : undefined)}
      className="cursor-pointer h-full"
    >
      <div className="flex gap-3">
        <div className={cn("flex-shrink-0 w-9 h-9 rounded-xl items-center justify-center", bgColor)}>
          <IconComponent className={cn("h-4 w-4", color)} aria-hidden="true" />
        </div>
        <div className="flex-1 min-w-0">
          <h4 className="text-sm font-semibold text-foreground truncate">{action.title}</h4>
          <p className="mt-0.5 text-xs text-muted-foreground line-clamp-1">{action.description}</p>
          {action.badgeLabel && (
            <Badge variant={action.badgeVariant} size="sm" className="mt-2">{action.badgeLabel}</Badge>
          )}
        </div>
      </div>
    </Card>
  );
};

const EmptyState = ({ userRole, status, navigate }) => {
  if (userRole === "student" && !(status?.has_adviser)) {
    return (
      <Card variant="glass" padding="lg">
        <div className="flex gap-4">
          <div className="flex-shrink-0 w-12 h-12 rounded-2xl bg-brand-orange/10 flex items-center justify-center">
            <SearchIcon className="h-6 w-6 text-brand-orange" aria-hidden="true" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-foreground">Find your adviser</h3>
            <p className="mt-1 text-sm text-muted-foreground">
              Browse available advisers, check schedules, and send an application to get started.
            </p>
            <Button className="mt-4" size="sm" onClick={() => navigate("/advisers")}>
              Find Adviser
            </Button>
          </div>
        </div>
      </Card>
    );
  }

  if (userRole === "adviser" && (status?.advisee_count || 0) === 0) {
    return (
      <Card variant="glass" padding="lg">
        <div className="flex gap-4">
          <div className="flex-shrink-0 w-12 h-12 rounded-2xl bg-brand-green/10 flex items-center justify-center">
            <UserPlusIcon className="h-6 w-6 text-brand-green" aria-hidden="true" />
          </div>
          <div className="flex-1">
            <h3 className="text-lg font-bold text-foreground">Waiting for students</h3>
            <p className="mt-1 text-sm text-muted-foreground">
              Your profile is active. Students will send applications once they find your expertise matching.
            </p>
            <Button variant="secondary" className="mt-4" size="sm" onClick={() => navigate("/settings")}>
              Complete Profile
            </Button>
          </div>
        </div>
      </Card>
    );
  }

  return (
    <Card variant="glass" padding="lg">
      <div className="flex gap-4">
        <div className="flex-shrink-0 w-12 h-12 rounded-2xl bg-muted flex items-center justify-center">
          <CheckCircleIcon className="h-6 w-6 text-muted-foreground" aria-hidden="true" />
        </div>
        <div className="flex-1">
          <h3 className="text-lg font-bold text-foreground">All caught up!</h3>
          <p className="mt-1 text-sm text-muted-foreground">
            No immediate actions needed. Check back later or browse your schedule.
          </p>
        </div>
      </div>
    </Card>
  );
};

/**
 * Main NextActionNudge component - shows primary action + secondary actions
 * @param {NextActionNudgeProps} props
 */
export function NextActionNudge({
  userRole,
  status,
  notifications = [],
  applications = [],
  bookings = [],
  documents = [],
  milestones = [],
  navigate,
  className,
}) {
  const actions = React.useMemo(
    () =>
      generateNextActions({
        userRole,
        status,
        notifications,
        applications,
        bookings,
        documents,
        milestones,
        navigate,
      }),
    [userRole, status, notifications, applications, bookings, documents, milestones, navigate]
  );

  if (actions.length === 0) {
    return <EmptyState userRole={userRole} status={status} navigate={navigate} className={className} />;
  }

  const primary = actions[0];
  const secondaries = actions.slice(1, 3);

  return (
    <div className={cn("space-y-4", className)}>
      <PrimaryActionCard action={primary} navigate={navigate} />

      {secondaries.length > 0 && (
        <div className="grid grid-cols-2 gap-3">
          {secondaries.map((action) => (
            <SecondaryActionCard key={action.type} action={action} navigate={navigate} />
          ))}
        </div>
      )}

      {actions.length > 3 && (
        <div className="text-center">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => navigate("/notifications")}
            className="text-muted-foreground hover:text-foreground"
          >
            +{actions.length - 3} more in Notifications
          </Button>
        </div>
      )}
    </div>
  );
}

/**
 * Convenience component for home screen integration
 * @param {NextActionNudgeProps} props
 */
export function NextActionHome(props) {
  return <NextActionNudge {...props} />;
}