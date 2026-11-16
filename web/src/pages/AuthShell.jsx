import { Link, useLocation } from "react-router-dom";
import {
  ArrowLeft, BookOpenCheck, CalendarDays, Check,
  GraduationCap, MessageCircle, Sparkles, Target, Users,
} from "lucide-react";
import Logo from "@/components/Logo";
import { GlassCard } from "@/components/ui/bento";

const SHOWCASE = {
  choose: {
    eyebrow: "A WORLD OF PROGRESS",
    title: "Big goals feel lighter together.",
    description: "Find your people, make a plan, and watch your research take shape.",
    cardTitle: "Your research journey",
    steps: ["Find your people", "Plan a consultation", "Make your next move"],
  },
  student: {
    eyebrow: "YOUR STUDENT SPACE",
    title: "Your next big idea starts here.",
    description: "Meet an adviser who gets your goals and keep the whole journey in view.",
    cardTitle: "Research project",
    steps: ["Match with an adviser", "Build your project plan", "Share progress together"],
  },
  adviser: {
    eyebrow: "YOUR ADVISER SPACE",
    title: "Help good ideas grow.",
    description: "Meet the right research teams and keep every conversation moving forward.",
    cardTitle: "Advising workspace",
    steps: ["Connect with students", "Plan your sessions", "Guide each milestone"],
  },
};

function AuthShowcase({ role }) {
  const content = SHOWCASE[role] || SHOWCASE.choose;
  const isAdviser = role === "adviser";

  return (
    <aside className={`auth-showcase auth-showcase--${role}`} aria-label="How AdviserLink helps your research">
      <div className="auth-showcase-copy">
        <span className="auth-showcase-eyebrow"><Sparkles size={14} /> {content.eyebrow}</span>
        <h2>{content.title}</h2>
        <p>{content.description}</p>
      </div>

      <div className="auth-world">
        <img
          className="auth-team-image"
          src={`${import.meta.env.BASE_URL}adviserlink-research-team.png`}
          alt="Students and advisers collaborating on a research project"
        />
        <div className="auth-floating-card auth-floating-card--match" key={`match-${role}`}>
          <span className="auth-floating-icon">
            {isAdviser ? <Users size={17} /> : <GraduationCap size={17} />}
          </span>
          <span><b>{isAdviser ? "New research team" : "A great match"}</b><small>{isAdviser ? "A new idea is ready to grow" : "Expertise meets your idea"}</small></span>
          <span className="auth-match-status"><Check size={12} /></span>
        </div>
        <div className="auth-floating-card auth-floating-card--session">
          <span className="auth-session-icon"><CalendarDays size={16} /></span>
          <span><small>NEXT UP · 10:30 AM</small><b>Research check-in</b></span>
          <MessageCircle size={15} className="auth-session-message" />
        </div>
        <div className="auth-world-caption">
          <span className="auth-caption-mark"><BookOpenCheck size={15} /></span>
          <span><small>ADVISERLINK WORKSPACE</small><b>Every next step, connected.</b></span>
          <span className="auth-caption-spark"><Sparkles size={15} /></span>
        </div>
      </div>

      <div className="auth-journey-card" key={`journey-${role}`}>
        <div className="auth-journey-heading">
          <span className="auth-journey-icon"><Target size={16} /></span>
          <span><small>ONE STEP AT A TIME</small><b>{content.cardTitle}</b></span>
          <span className="auth-journey-avatars" aria-hidden="true"><i>S</i><i>A</i></span>
        </div>
        <div className="auth-journey-steps">
          {content.steps.map((step, index) => (
            <div className="auth-journey-step" key={step}>
              <span className={index === 0 ? "is-complete" : ""}>{index === 0 ? <Check size={11} /> : `0${index + 1}`}</span>
              <b>{step}</b>
            </div>
          ))}
        </div>
      </div>

      <div className="auth-showcase-bottom">
        <span>Made for students and advisers.</span>
        <span className="auth-showcase-dots"><i /><i /><i /></span>
      </div>
    </aside>
  );
}

export default function AuthShell({ title, subtitle, children, role = "choose" }) {
  const { pathname } = useLocation();
  const isRegister = pathname === "/register";

  return (
    <div className={`auth-shell auth-shell--${isRegister ? "register" : "login"} relative flex min-h-screen flex-col`}>
      <header className="auth-header mx-auto flex w-full max-w-6xl items-center justify-between px-4 py-4">
        <Link to="/" className="auth-back-link inline-flex items-center gap-2 text-sm font-semibold text-muted-foreground transition-colors hover:text-foreground">
          <ArrowLeft className="h-4 w-4" />
          Home
        </Link>
        <Logo size={36} withName />
      </header>

      <main className="auth-main mx-auto grid w-full max-w-6xl flex-1 items-stretch gap-5 px-4 pb-5 pt-1 lg:grid-cols-[minmax(0,1.08fr)_minmax(420px,.92fr)]">
        <AuthShowcase role={role} />

        <GlassCard variant="default" padding="none" className="auth-form-card">
          <div className="auth-form-inner">
            <nav className="auth-mode-tabs" aria-label="Account access">
              <Link to="/register" aria-current={isRegister ? "page" : undefined} className={isRegister ? "is-active" : ""}>
                Sign up
              </Link>
              <Link to="/login" aria-current={!isRegister ? "page" : undefined} className={!isRegister ? "is-active" : ""}>
                Log in
              </Link>
            </nav>
            <div className="auth-form-heading">
              <span className="auth-form-overline">{isRegister ? "A FRESH START" : "WELCOME BACK"}</span>
              <h1>{title}</h1>
              <p>{subtitle}</p>
            </div>
            <div className="auth-form-content">{children}</div>
            <p className="auth-form-footer">AdviserLink <span>·</span> ISU Echague</p>
          </div>
        </GlassCard>
      </main>

    </div>
  );
}
