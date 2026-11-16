import { useCallback, useEffect, useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { LogOut, Menu, Settings as SettingsIcon, Sun, Moon, Monitor, ChevronDown, Mail, Bell as BellIcon, LayoutDashboard, Calendar, Users, UserCheck, ClipboardList, Target, BarChart3, BookOpen, FileText, Shield } from "lucide-react";
import { getStatus } from "@/api";
import NotificationBell from "@/components/Bell";
import ConsultationAlert from "@/components/ConsultationAlert";
import Logo from "@/components/Logo";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { useTheme } from "@/context/ThemeContext";
import { GlassCard, IconButton, StatusPill } from "@/components/ui/bento";

// Ano lang ang dapat makita ng user ayon sa kalagayan niya (hal. walang Schedule/Board kung wala pang adviser)
export function allowedFor(user, status) {
  if (user.role === "admin") return ["analytics", "users", "adviser-approvals", "audit-log", "messages", "notifications", "settings"];
  if (user.role === "student" && user.student_group_role === "member") {
    if (status.has_adviser) return ["schedule", "applications", "board", "milestones", "notifications", "settings"];
    return status.has_group
      ? ["applications", "notifications", "settings"]
      : ["applications", "groups", "notifications", "settings"];
  }
  if (user.role === "student") return status.has_adviser
    ? ["schedule", "applications", "groups", "board", "milestones", "notifications", "settings"]
    : ["advisers", "applications", "groups", "notifications", "settings"];
  return status.advisee_count > 0
    ? ["schedule", "applications", "board", "milestones", "insights", "notifications", "settings"]
    : ["applications", "notifications", "settings"];
}

export function homeFor(user, status) {
  if (user.role === "admin") return "/analytics";
  if (user.role === "student" && user.student_group_role === "member") {
    if (status.has_adviser) return "/schedule";
    return status.has_group ? "/applications" : "/groups";
  }
  if (user.role === "student") return status.has_adviser ? "/schedule" : "/advisers";
  if (!status.profile_ready) return "/settings";
  return status.advisee_count > 0 ? "/schedule" : "/applications";
}

function labelFor(key, user) {
  if (key === "groups" && user?.role === "student" && user.student_group_role !== "member") return "Find Members";
  return LABELS[key];
}

const LABELS = {
  schedule: "Schedule",
  advisers: "Find Adviser",
  applications: "Requests",
  groups: "Find a Group",
  board: "Board",
  milestones: "Milestones",
  insights: "Insights",
  analytics: "Analytics",
  users: "Users",
  "adviser-approvals": "Adviser approvals",
  "audit-log": "Audit Log",
  settings: "Settings",
};

const ICONS = {
  schedule: Calendar,
  advisers: Users,
  applications: ClipboardList,
  groups: Users,
  board: Target,
  milestones: Target,
  insights: BarChart3,
  analytics: BarChart3,
  users: Users,
  "adviser-approvals": UserCheck,
  "audit-log": FileText,
  settings: SettingsIcon,
};

function NavItem({ key, label, isActive, badge, icon: Icon, onClick }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "flex items-center gap-2 w-full px-4 py-3 text-left rounded-xl transition-colors",
        isActive
          ? "bg-gradient-to-r from-primary/20 to-primary/10 text-primary font-semibold"
          : "text-muted-foreground hover:bg-muted hover:text-foreground"
      )}
    >
      <Icon className="h-5 w-5 shrink-0" aria-hidden="true" />
      <span className="font-medium">{label}</span>
      {badge && <span className="ml-auto rounded-full bg-primary px-2 py-0.5 text-xs font-bold text-primary-foreground">{badge}</span>}
    </button>
  );
}

function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  // Cycle: light -> dark -> system -> light (or just light <-> dark)
  const cycleTheme = () => {
    if (theme === "light") setTheme("dark");
    else if (theme === "dark") setTheme("system");
    else setTheme("light");
  };

  // Determine current effective theme for icon
  const isDark = theme === "dark" || (theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);

  return (
    <IconButton
      variant="ghost"
      size="default"
      onClick={cycleTheme}
      aria-label={`Theme: ${theme}. Click to cycle.`}
      className="relative h-10 w-10 rounded-full"
    >
      {isDark ? <Moon className="h-5 w-5" /> : <Sun className="h-5 w-5" />}
      {theme === "system" && (
        <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-muted text-[10px] font-bold">
          A
        </span>
      )}
    </IconButton>
  );
}

function NavIconButton({ icon: Icon, ariaLabel, badge, isActive, onClick }) {
  return (
    <IconButton
      variant={isActive ? "primary" : "ghost"}
      size="default"
      onClick={onClick}
      aria-label={ariaLabel}
      className="relative"
    >
      <Icon className="h-5 w-5" aria-hidden="true" />
      {badge && badge > 0 && (
        <span className="absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-destructive text-destructive-foreground text-[10px] font-extrabold">
          {badge > 9 ? "9+" : badge}
        </span>
      )}
    </IconButton>
  );
}

export default function Layout({ user, setUser, onLogout }) {
  const navigate = useNavigate();
  const [status, setStatus] = useState(null);
  const [refreshAnimationKey, setRefreshAnimationKey] = useState(0);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [statusError, setStatusError] = useState(false);
  const refresh = useCallback(() => getStatus().then(setStatus).catch(() => { setStatusError(true); setStatus({}); }), []);
  const triggerRefreshAnimation = useCallback(() => setRefreshAnimationKey((key) => key + 1), []);
  useEffect(() => { refresh(); }, [refresh, user?.user_id]);

  if (status === null) return <p className="p-8 text-center text-muted-foreground">Loading…</p>;
  const allowed = allowedFor(user, status);
  const home = homeFor(user, status);
  const navItems = allowed.filter((k) => k !== "notifications" && k !== "messages");

  return (
    <div className="app-workspace min-h-screen">
      {refreshAnimationKey > 0 && (
        <div
          key={refreshAnimationKey}
          className="refresh-feedback-flash"
          aria-hidden="true"
          onAnimationEnd={() => setRefreshAnimationKey(0)}
        />
      )}
      <ConsultationAlert user={user} />
      {/* Page background gradient - applied via CSS on body */}

      {/* Floating bento container */}
      <div className="relative z-10 mx-auto max-w-7xl">
        <GlassCard variant="brand" padding="none" className="workspace-frame rounded-[var(--radius-bento)] overflow-hidden shadow-bento">
          {/* Top Navigation */}
          <header className={cn(
            "dark workspace-header-dark border-b border-border/30 backdrop-blur-xl"
          )}>
            <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-x-6 gap-y-2 px-4 py-3">
              <NavLink
                to={home}
                onClick={() => setMobileMenuOpen(false)}
                className="flex items-center gap-2"
              >
                <Logo size={36} withName className="text-foreground" />
              </NavLink>

              {/* Desktop Navigation - Center Tabs */}
              <nav className="hidden md:flex md:order-none md:w-auto flex-1 justify-center gap-1 overflow-x-auto">
                {navItems.map((key) => {
                  const Icon = ICONS[key];
                  const isLast = key === navItems[navItems.length - 1];
                  return (
                    <NavLink
                      key={key}
                      to={`/${key}`}
                      onClick={() => setMobileMenuOpen(false)}
                      className={({ isActive }) =>
                        cn(
                          "relative flex items-center gap-1.5 whitespace-nowrap rounded-[var(--radius-tile)] px-4 py-2 text-sm font-semibold transition-all",
                          isActive
                            ? "bg-gradient-to-b from-primary/20 to-primary/10 text-primary shadow-[0_4px_14px_-4px_hsl(var(--primary)/0.4)] before:absolute before:inset-0 before:rounded-[var(--radius-tile)] before:bg-gradient-to-b before:from-primary/10 before:to-transparent"
                            : "text-muted-foreground hover:text-foreground hover:bg-muted/50"
                        )
                      }
                    >
                      <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
                      <span>{labelFor(key, user)}</span>
                      {(key === "applications" && status.pending_requests > 0) || (key === "adviser-approvals" && status.pending_advisers > 0) ? (
                        <span className="ml-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-primary px-1.5 text-[10px] font-extrabold text-primary-foreground">
                          {key === "applications" ? status.pending_requests : status.pending_advisers}
                        </span>
                      ) : null}
                    </NavLink>
                  );
                })}
              </nav>

              {/* Desktop Actions */}
              <div className="hidden md:flex items-center gap-2">
                <ThemeToggle />

                <NavIconButton
                  icon={Mail}
                  ariaLabel="Messages"
                  badge={status.unread_messages || 0}
                  onClick={() => navigate("/messages")}
                />
                <NotificationBell onPoll={refresh} />

                {/* User Dropdown */}
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <IconButton variant="ghost" size="default" className="relative h-11 w-11 rounded-full">
                      {user.profile_photo ? (
                        <img src={user.profile_photo} alt={user.name} className="h-11 w-11 rounded-full object-cover" />
                      ) : (
                        <div className="h-11 w-11 rounded-full bg-primary/20 flex items-center justify-center">
                          <span className="text-sm font-bold text-primary">{user.name.charAt(0).toUpperCase()}</span>
                        </div>
                      )}
                    </IconButton>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="w-56 glass-strong">
                    <div className="px-4 py-2 border-b border-border">
                      <p className="font-semibold truncate">{user.name}</p>
                      <p className="text-xs text-muted-foreground truncate">{user.email}</p>
                      <StatusPill tone={user.role === "student" ? "student" : user.role === "adviser" ? "adviser" : "admin"} className="mt-1" showDot>
                        {user.role.charAt(0).toUpperCase() + user.role.slice(1)}
                      </StatusPill>
                    </div>
                    <DropdownMenuItem onClick={() => navigate("/settings")}>Profile</DropdownMenuItem>
                    <DropdownMenuItem onClick={() => navigate("/settings")}>Settings</DropdownMenuItem>
                    <DropdownMenuItem className="text-destructive" onClick={onLogout}>
                      <LogOut className="mr-2 h-4 w-4" /> Log out
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>

              {/* Mobile Menu Button */}
              <Sheet open={mobileMenuOpen} onOpenChange={setMobileMenuOpen}>
                <SheetTrigger asChild>
                  <Button variant="ghost" size="icon" className="md:hidden"><Menu className="h-6 w-6" /></Button>
                </SheetTrigger>
                <SheetContent side="right" className="w-72 p-0">
                  <div className="p-4 border-b border-border">
                    <button type="button" onClick={() => { setMobileMenuOpen(false); navigate("/settings"); }} aria-label="Open profile settings" className="flex w-full items-center gap-3 rounded-xl px-2 py-2 text-left transition-colors hover:bg-muted/60">
                      {user.profile_photo ? (
                        <img src={user.profile_photo} alt={user.name} className="h-10 w-10 rounded-full object-cover" />
                      ) : (
                        <div className="h-10 w-10 rounded-full bg-primary/20 flex items-center justify-center">
                          <span className="text-lg font-bold text-primary">{user.name.charAt(0).toUpperCase()}</span>
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <p className="font-semibold truncate">{user.name}</p>
                        <p className="text-xs text-muted-foreground truncate">{user.email}</p>
                      </div>
                    </button>
                  </div>
                  <nav className="p-2 space-y-1">
                    {navItems.map((key) => {
                      const Icon = ICONS[key];
                      const badge = key === "applications"
                        ? status.pending_requests
                        : key === "adviser-approvals"
                          ? status.pending_advisers
                          : null;
                      return (
                        <NavLink
                          key={key}
                          to={`/${key}`}
                          onClick={() => setMobileMenuOpen(false)}
                          className={({ isActive }) => cn(
                            "flex w-full items-center gap-2 rounded-xl px-4 py-3 text-left no-underline transition-colors",
                            isActive
                              ? "bg-gradient-to-r from-primary/20 to-primary/10 font-semibold text-primary"
                              : "text-muted-foreground hover:bg-muted hover:text-foreground"
                          )}
                        >
                          <Icon className="h-5 w-5 shrink-0" aria-hidden="true" />
                          <span className="font-medium">{labelFor(key, user)}</span>
                          {badge > 0 && (
                            <span className="ml-auto rounded-full bg-primary px-2 py-0.5 text-xs font-bold text-primary-foreground">
                              {badge > 9 ? "9+" : badge}
                            </span>
                          )}
                        </NavLink>
                      );
                    })}
                    <div className="pt-2 border-t border-border">
                      {user.role === "admin" && (
                        <NavItem
                          label="Messages"
                          icon={Mail}
                          badge={status.unread_messages || null}
                          onClick={() => { setMobileMenuOpen(false); navigate("/messages"); }}
                        />
                      )}
                      <NavItem
                        label="Notifications"
                        icon={BellIcon}
                        isActive={false}
                        badge={status.unread_count || null}
                        onClick={() => { setMobileMenuOpen(false); navigate("/notifications"); }}
                      />
                    </div>
                  </nav>
                  <div className="p-4 border-t border-border space-y-3">
                    <div>
                      <p className="text-xs text-muted-foreground mb-2">Theme</p>
                      <ThemeToggle />
                    </div>
                    <Button variant="outline" className="w-full justify-start gap-2" onClick={() => { setMobileMenuOpen(false); onLogout(); }}>
                      <LogOut className="h-4 w-4" /> Log out
                    </Button>
                  </div>
                </SheetContent>
              </Sheet>
            </div>
          </header>

          {/* Page Content */}
          <main className={cn("mx-auto grid max-w-6xl gap-5 px-4 py-6", refreshAnimationKey > 0 && "refresh-feedback-rise")}>
            <Outlet context={{ user, setUser, status, refresh, triggerRefreshAnimation, allowed, home }} />
          </main>
        </GlassCard>
      </div>
    </div>
  );
}