import { useEffect, useRef, useState } from "react";
import { ArrowLeft, ArrowRight, BarChart3, CalendarCheck, CheckCircle2, ListChecks, Search, UserCheck } from "lucide-react";
import { Link } from "react-router-dom";
import Logo from "@/components/Logo";

const SLIDES = [
  {
    Icon: Search,
    title: "Find the right adviser",
    description: "Search by topic, skill, or name and find the right match for your research.",
    examples: ["Search by research topic", "Compare specializations", "Check open advisee slots"],
  },
  {
    Icon: UserCheck,
    title: "Apply and get approved",
    description: "Send your proposal to an adviser and follow its status from your account.",
    examples: ["Submit a project brief", "Track pending requests", "See approval updates"],
  },
  {
    Icon: CalendarCheck,
    title: "Book in a few taps",
    description: "Choose an available consultation time and keep the details in one place.",
    examples: ["Browse open times", "Avoid double bookings", "Get meeting reminders"],
  },
  {
    Icon: ListChecks,
    title: "Track every task",
    description: "Organize research work by stage and keep adviser feedback alongside it.",
    examples: ["Plan next steps", "Share project files", "Review adviser comments"],
  },
  {
    Icon: BarChart3,
    title: "See your progress",
    description: "Keep milestones, consultation history, and project progress visible.",
    examples: ["Follow thesis milestones", "Review consultation history", "See progress at a glance"],
  },
];

export default function Landing() {
  const carouselRef = useRef(null);
  const settleTimer = useRef(null);
  const [index, setIndex] = useState(0);
  const [settledIndex, setSettledIndex] = useState(0);
  const count = SLIDES.length + 1;

  useEffect(() => () => window.clearTimeout(settleTimer.current), []);

  function onScroll() {
    const carousel = carouselRef.current;
    if (!carousel) return;
    const center = carousel.scrollLeft + carousel.clientWidth / 2;
    let nearest = 0;
    let nearestDistance = Infinity;
    [...carousel.children].forEach((slide, slideIndex) => {
      const distance = Math.abs(slide.offsetLeft + slide.offsetWidth / 2 - center);
      if (distance < nearestDistance) {
        nearest = slideIndex;
        nearestDistance = distance;
      }
    });
    setIndex(nearest);
    window.clearTimeout(settleTimer.current);
    settleTimer.current = window.setTimeout(() => setSettledIndex(nearest), 140);
  }

  function goToSlide(target) {
    const slide = carouselRef.current?.children[Math.max(0, Math.min(target, count - 1))];
    slide?.scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
  }

  return (
    <div className="landing-page relative flex min-h-screen flex-col overflow-hidden">
      <header className="relative z-10 mx-auto flex w-full max-w-6xl items-center justify-between px-4 py-4">
        <Logo size={36} withName />
        <nav aria-label="Account" className="flex items-center gap-2">
          <Link to="/login" className="rounded-full px-4 py-2 text-sm font-semibold text-foreground transition-colors hover:bg-background/60">
            Log in
          </Link>
          <Link to="/register" className="rounded-full bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground shadow-tile-glow transition-transform hover:scale-[1.03]">
            Get started
          </Link>
        </nav>
      </header>

      <main className="relative z-10 flex min-h-0 flex-1 items-center">
        <div
          ref={carouselRef}
          onScroll={onScroll}
          className="landing-track hide-scrollbar flex w-full snap-x snap-mandatory gap-5 overflow-x-auto scroll-smooth px-[max(1rem,calc(50vw-15rem))] py-8"
        >
          <section className={`landing-glass-panel relative flex min-h-[29rem] w-[min(86vw,30rem)] flex-none snap-center flex-col justify-center overflow-hidden rounded-[var(--radius-bento)] border border-border/50 bg-gradient-to-br from-primary/20 via-primary/10 to-background px-6 py-10 text-center sm:min-h-[32rem] sm:px-10 ${settledIndex === 0 ? "landing-slide-active" : ""}`}>
            <div aria-hidden="true" className="absolute inset-0 opacity-50" style={{ backgroundImage: "repeating-linear-gradient(165deg, transparent 0 10px, hsl(var(--primary) / .08) 10px 11px)" }} />
            <div className="relative mx-auto w-full max-w-sm">
              <div className="mx-auto grid h-24 w-24 place-items-center rounded-[28px] border border-white/40 bg-white/80 shadow-lg backdrop-blur-xl">
                <Logo size={72} />
              </div>
              <p className="mt-7 text-xs font-bold uppercase text-primary">Thesis &amp; capstone advising</p>
              <h1 className="mt-3 text-4xl font-extrabold leading-tight sm:text-5xl">Welcome to AdviserLink</h1>
              <p className="mx-auto mt-3 max-w-xs text-sm leading-6 text-muted-foreground sm:text-base">
                Hi there. Find an adviser, plan consultations, and move your research forward.
              </p>
              <div className="mt-7 flex flex-wrap justify-center gap-3">
                <Link to="/register" className="rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-foreground shadow-tile-glow transition-transform hover:scale-[1.03]">
                  Create your account
                </Link>
                <Link to="/login" className="rounded-full border border-border bg-background/75 px-6 py-3 text-sm font-bold text-foreground transition-colors hover:bg-background">
                  Log in
                </Link>
              </div>
              <p className="mt-5 text-xs text-muted-foreground">Swipe to see how it works</p>
            </div>
          </section>

          {SLIDES.map(({ Icon, title, description, examples }, slideIndex) => (
            <section key={title} className={`landing-glass-panel relative flex min-h-[29rem] w-[min(86vw,30rem)] flex-none snap-center flex-col overflow-hidden rounded-[var(--radius-bento)] border border-border/50 bg-gradient-to-br from-primary/15 via-primary/5 to-background p-6 text-foreground sm:min-h-[32rem] sm:p-8 ${settledIndex === slideIndex + 1 ? "landing-slide-active" : ""}`}>
              <div aria-hidden="true" className="absolute inset-0 opacity-40" style={{ backgroundImage: "repeating-linear-gradient(165deg, transparent 0 10px, hsl(var(--primary) / .07) 10px 11px)" }} />
              <div className="relative flex h-full flex-col">
                <div className="flex items-center justify-between">
                  <span className="grid h-12 w-12 place-items-center rounded-2xl bg-primary text-primary-foreground shadow-tile-glow"><Icon className="h-6 w-6" /></span>
                  <span className="rounded-full border border-primary/25 bg-primary/10 px-3 py-1 text-xs font-bold text-primary">STEP {slideIndex + 1}</span>
                </div>
                <h2 className="mt-7 text-3xl font-extrabold leading-tight">{title}</h2>
                <p className="mt-3 text-sm leading-6 text-muted-foreground">{description}</p>
                <div className="mt-auto grid gap-2 pt-8">
                  {examples.map((example, exampleIndex) => (
                    <div key={example} className="landing-feature-row flex items-center gap-3 rounded-2xl border border-border/40 bg-background/75 px-4 py-3 text-sm font-medium">
                      <CheckCircle2 className="h-4 w-4 flex-none text-primary" />
                      <span>{example}</span>
                      <span className="ml-auto text-xs text-muted-foreground">0{exampleIndex + 1}</span>
                    </div>
                  ))}
                </div>
              </div>
            </section>
          ))}
        </div>
      </main>

      <nav aria-label="Welcome slides" className="landing-controls relative z-10 mx-auto mb-4 flex w-[min(94vw,34rem)] items-center gap-3 rounded-full border border-border/40 bg-background/75 p-2 backdrop-blur-xl">
        <div className="flex items-center gap-1.5 pl-3">
          {Array.from({ length: count }, (_, slideIndex) => (
            <button key={slideIndex} type="button" aria-label={`Go to slide ${slideIndex + 1}`} onClick={() => goToSlide(slideIndex)} className={`h-1.5 rounded-full transition-all ${slideIndex === index ? "w-6 bg-primary" : "w-3 bg-muted-foreground/35"}`} />
          ))}
        </div>
        <div className="ml-auto flex items-center gap-2">
          <button type="button" aria-label="Previous" disabled={index === 0} onClick={() => goToSlide(index - 1)} className="grid h-10 w-10 place-items-center rounded-full border border-border disabled:opacity-35"><ArrowLeft className="h-4 w-4" /></button>
          <button type="button" aria-label="Next" disabled={index === count - 1} onClick={() => goToSlide(index + 1)} className="grid h-10 w-10 place-items-center rounded-full bg-primary text-primary-foreground disabled:opacity-35"><ArrowRight className="h-4 w-4" /></button>
        </div>
      </nav>
    </div>
  );
}