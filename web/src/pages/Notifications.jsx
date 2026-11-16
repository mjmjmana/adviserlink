import { useCallback, useEffect, useMemo, useState } from "react";
import { Link, useOutletContext, useSearchParams } from "react-router-dom";
import { Bell, CalendarClock, FileText, ListChecks, MessageSquare, UserCheck } from "lucide-react";
import { getNotifications, readAllNotifications, readNotification } from "@/api";
import { StatusPill } from "@/components/ui/bento";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { GlassCard, CardHeader, PersonChip, EmptyState, IconButton } from "@/components/ui/bento";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

// Hinuhulaan ang uri ng notification mula sa mensahe para magkaroon ng icon, pamagat, at "Go to" na link
function kindOf(notification, role) {
  const m = notification.message.toLowerCase();
  const moderation = role === "admin" && m.match(/chat moderation alert for application (\d+)/i);
  if (moderation) {
    return {
      label: "Message moderation",
      Icon: MessageSquare,
      to: "/messages",
      applicationId: Number(notification.related_application_id) || Number(moderation[1]),
      messageId: Number(notification.related_message_id) || null,
      actionLabel: "Open flagged conversation",
    };
  }
  if (/^new message from /i.test(notification.message)) {
    return {
      label: "Message",
      Icon: MessageSquare,
      to: role === "admin" ? "/messages" : "/board",
      applicationId: Number(notification.related_application_id) || null,
      messageId: Number(notification.related_message_id) || null,
      actionLabel: "Open conversation",
    };
  }
  if (/new adviser registration|waiting for your approval/.test(m)) return { label: "Adviser approval", Icon: UserCheck, to: "/adviser-approvals" };
  if (/requested to join your project group/.test(m)) return { label: "Group request", Icon: UserCheck, to: "/applications" };
  if (/request to join the project group/.test(m)) return { label: "Group request", Icon: UserCheck, to: role === "student" ? "/groups" : "/applications" };
  if (/group invitation|invited you to join a project group/.test(m)) return { label: "Group", Icon: UserCheck, to: "/applications" };
  if (/uploaded/.test(m)) return { label: "File", Icon: FileText, to: "/board" };
  if (/task due|milestone due/.test(m)) return { label: "Deadline", Icon: ListChecks, to: m.includes("milestone") ? "/milestones" : "/board" };
  if (/moved|commented/.test(m)) return { label: "Board", Icon: ListChecks, to: "/board" };
  if (/approved your application/.test(m)) return { label: "Application approved", Icon: CalendarClock, to: "/schedule" };
  if (/applied|application/.test(m)) return { label: "Application", Icon: UserCheck, to: role === "adviser" ? "/applications" : "/advisers" };
  if (/consultation|meeting|reminder|cancelled|booked/.test(m)) return { label: "Consultation", Icon: CalendarClock, to: "/schedule" };
  return { label: "Update", Icon: Bell, to: "/home" };
}

function actionHref(kind) {
  if (!kind.applicationId) return kind.to;
  const params = new URLSearchParams({
    [kind.to === "/board" ? "app" : "application"]: String(kind.applicationId),
  });
  if (kind.messageId) params.set("message", String(kind.messageId));
  return `${kind.to}?${params}`;
}

function actionText(kind) {
  if (kind.actionLabel) return kind.actionLabel;
  const labels = {
    "/schedule": "Schedule",
    "/board": "Board",
    "/applications": "Requests",
    "/advisers": "Find adviser",
    "/adviser-approvals": "Adviser approvals",
    "/messages": "Messages",
  };
  return `Go to ${labels[kind.to] || "Home"}`;
}

export default function Notifications() {
  const { user, allowed, refresh } = useOutletContext();
  const [params, setParams] = useSearchParams();
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState("all");
  const [loaded, setLoaded] = useState(false);
  const openId = Number(params.get("open")) || null;

  const load = useCallback(() => getNotifications(200).then((d) => { setItems(d.items); setLoaded(true); refresh(); }).catch(() => setLoaded(true)), [refresh]);
  useEffect(() => { load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, [load]);

  const shown = useMemo(() => (filter === "unread" ? items.filter((n) => !n.is_read) : items), [items, filter]);
  const selected = items.find((n) => n.notification_id === openId) || null;

  async function open(n) {
    setParams({ open: String(n.notification_id) }, { replace: true });
    if (!n.is_read) {
      setItems((cur) => cur.map((x) => (x.notification_id === n.notification_id ? { ...x, is_read: 1 } : x)));
      await readNotification(n.notification_id).catch(() => {});
      refresh();
    }
  }
  async function markAll() {
    await readAllNotifications().catch(() => {});
    load();
  }

  const unread = items.filter((n) => !n.is_read).length;
  const kind = selected ? kindOf(selected, user.role) : null;

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="grid gap-1">
          <h1 className="text-3xl font-extrabold tracking-tight">Notifications</h1>
          <p className="text-foreground/70">{unread ? `${unread} unread` : "You're all caught up."}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Tabs value={filter} onValueChange={setFilter}>
            <TabsList className="bg-muted text-foreground"><TabsTrigger value="all"><span>All</span></TabsTrigger><TabsTrigger value="unread"><span>Unread</span></TabsTrigger></TabsList>
          </Tabs>
          <Button variant="outline" size="sm" disabled={!unread} onClick={markAll}>Mark all as read</Button>
        </div>
      </div>

      <div className="grid items-stretch gap-5 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)]">
        <GlassCard className="max-h-[70vh] overflow-hidden flex flex-col">
          <CardHeader icon={<Bell className="h-5 w-5" />} title="Recent activity" iconColor="primary" />
          <div className="flex-1 overflow-y-auto p-4 grid gap-2">
            {loaded && shown.length === 0 && (
              <EmptyState
                icon={<Bell className="h-12 w-12" />}
                title={filter === "unread" ? "No unread notifications" : "Nothing yet"}
                description={filter === "unread" ? "All caught up! New notifications will appear here." : "Notifications will appear when you receive updates."}
              />
            )}
            {shown.map((n) => {
              const notificationKind = kindOf(n, user.role);
              const { Icon } = notificationKind;
              const active = n.notification_id === openId;
              const canOpen = allowed.includes(notificationKind.to.replace("/", ""))
                && (!notificationKind.actionLabel || notificationKind.applicationId);
              return (
                <div
                  key={n.notification_id}
                  className={cn(
                    "rounded-[var(--radius-card)] transition-colors",
                    active ? "bg-primary/10 text-foreground" : n.is_read ? "bg-muted/50 hover:bg-muted" : "bg-primary/5 hover:bg-primary/10"
                  )}
                >
                  <button
                    type="button"
                    onClick={() => open(n)}
                    className="flex w-full items-start gap-3 p-3 text-left"
                  >
                    <span className={cn("mt-0.5 grid h-9 w-9 shrink-0 place-items-center rounded-full", active ? "bg-primary/20 text-primary" : "bg-muted text-foreground")}><Icon className="h-4 w-4" /></span>
                    <span className="min-w-0 flex-1">
                      <span className={cn("line-clamp-2 text-sm", !n.is_read && !active && "font-bold")}>{n.message}</span>
                      <small className={cn("mt-0.5 block text-xs", active ? "text-primary/80" : "text-muted-foreground")}>{n.date_sent}</small>
                    </span>
                    {!n.is_read && !active && <span className="mt-2 h-2.5 w-2.5 shrink-0 rounded-full bg-primary" />}
                  </button>
                  {canOpen && (
                    <Button asChild size="sm" variant="outline" className="mb-3 ml-12">
                      <Link
                        to={actionHref(notificationKind)}
                        target={user.role === "admin" ? "_blank" : undefined}
                        rel={user.role === "admin" ? "noopener noreferrer" : undefined}
                        onClick={() => {
                          if (!n.is_read) readNotification(n.notification_id).then(refresh).catch(() => {});
                        }}
                      >
                        {actionText(notificationKind)}
                      </Link>
                    </Button>
                  )}
                </div>
              );
            })}
          </div>
        </GlassCard>

        <GlassCard className="min-h-[18rem] p-6 flex flex-col">
          {!selected && (
            <EmptyState
              icon={<Bell className="h-12 w-12" />}
              title="Select a notification"
              description="Click on a notification from the list to read its details and take action."
            />
          )}
          {selected && (
            <div className="grid content-start gap-4 flex-1">
              <div className="flex items-center gap-3">
                <span className="grid h-12 w-12 place-items-center rounded-full bg-muted text-foreground"><kind.Icon className="h-5 w-5" /></span>
                <div>
                  <StatusPill tone="primary">{kind.label}</StatusPill>
                  <p className="mt-1 text-xs text-muted-foreground">{selected.date_sent}</p>
                </div>
              </div>
              <p className="text-lg font-semibold leading-snug">{selected.message}</p>
              {allowed.includes(kind.to.replace("/", "")) && (!kind.actionLabel || kind.applicationId) && (
                <Button asChild className="w-fit">
                  <Link
                    to={actionHref(kind)}
                    target={user.role === "admin" && kind.applicationId ? "_blank" : undefined}
                    rel={user.role === "admin" && kind.applicationId ? "noopener noreferrer" : undefined}
                  >
                    {actionText(kind)}
                  </Link>
                </Button>
              )}
            </div>
          )}
        </GlassCard>
      </div>
    </>
  );
}