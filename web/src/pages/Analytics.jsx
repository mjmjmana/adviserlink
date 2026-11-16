import { useEffect, useState } from "react";
import { useNavigate, useOutletContext } from "react-router-dom";
import { AlertTriangle, ArrowLeft, BarChart3, CheckCircle2, Lightbulb, RefreshCw, Search, Target, TrendingUp, Users, UserCheck, Calendar, ClipboardList, Star } from "lucide-react";
import { Bar, BarChart, CartesianGrid, Cell, Legend, Line, LineChart, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { getAnalytics, getAnalyticsDetails } from "@/api";
import { StatusPill } from "@/components/ui/bento";
import { Button } from "@/components/ui/button";
import { GlassCard, CardHeader, StatTile } from "@/components/ui/bento";
import { Notice } from "@/components/ui/alert";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

// Brand color palette for charts
const ORANGE = "hsl(var(--primary))";
const INK = "hsl(var(--foreground))";
const SAGE = "hsl(var(--success))";
const SAND = "hsl(var(--muted-foreground))";
const RED = "hsl(var(--error))";
const AMBER = "hsl(var(--warning))";
const PURPLE = "hsl(var(--role-adviser))";

const PIE = { pending: AMBER, approved: SAGE, declined: RED, confirmed: ORANGE, completed: SAGE, cancelled: RED, Adviser: INK, Student: ORANGE, Unknown: SAND };
const tick = { fill: INK, fontSize: 12 };
const tip = { contentStyle: { borderRadius: 12, border: "none", background: "hsl(var(--popover))", color: INK, fontWeight: 600 } };

function ChartCard({ title, description, note, children, className, onExpand }) {
  return (
    <GlassCard className={className}>
      <div className="flex items-start justify-between gap-2">
        <CardHeader icon={<BarChart3 className="h-5 w-5" />} title={title} description={description} iconColor="primary" />
        {onExpand && <Button variant="outline" size="sm" className="shrink-0" onClick={onExpand}>View records</Button>}
      </div>
      <div className="min-h-[15rem]">{children}{note && <p className="mt-3 rounded-xl bg-muted/50 px-3 py-2 text-xs text-muted-foreground"><b>In plain words:</b> {note}</p>}</div>
    </GlassCard>
  );
}

function Bars({ data, color = ORANGE, unit = "", height = 240 }) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={data} margin={{ top: 8, right: 8, left: -18, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
        <XAxis dataKey="name" tick={tick} tickLine={false} axisLine={false} />
        <YAxis tick={tick} tickLine={false} axisLine={false} allowDecimals={false} />
        <Tooltip {...tip} formatter={(v) => `${v}${unit}`} cursor={{ fill: "hsl(var(--primary) / 0.06)" }} />
        <Bar dataKey="value" fill={color} radius={[8, 8, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}

function Donut({ data, height = 240 }) {
  const total = data.reduce((s, d) => s + d.value, 0);
  if (!total) return <p className="grid h-[240px] place-items-center text-sm text-muted-foreground">No data yet.</p>;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <PieChart>
        <Pie data={data} dataKey="value" nameKey="name" innerRadius={55} outerRadius={85} paddingAngle={3} stroke="none">
          {data.map((d) => <Cell key={d.name} fill={PIE[d.name] || SAND} />)}
        </Pie>
        <Tooltip {...tip} />
        <Legend iconType="circle" wrapperStyle={{ fontSize: 12, color: INK }} />
      </PieChart>
    </ResponsiveContainer>
  );
}

const RISK = { Complete: "success", "On track": "success", "At risk": "warning", Stalled: "destructive", "No tasks yet": "default" };
const REC = { warn: [AlertTriangle, "bg-warning/10 text-warning"], info: [Lightbulb, "bg-muted/50"], ok: [CheckCircle2, "bg-success/10 text-success"] };

export default function Analytics() {
  const { user, triggerRefreshAnimation } = useOutletContext();
  const navigate = useNavigate();
  const isAdmin = user.role === "admin";
  const [report, setReport] = useState(null);
  const [error, setError] = useState("");
  const [detail, setDetail] = useState(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailError, setDetailError] = useState("");
  const [detailQuery, setDetailQuery] = useState("");
  const load = () => { setError(""); getAnalytics().then(setReport).catch((e) => setError(e.message)); };
  useEffect(load, []);
  const openDetails = async (category, title, description, localRows) => {
    setDetail({ category, title, description, rows: localRows || [] });
    setDetailQuery("");
    setDetailError("");
    if (localRows) return;
    setDetailLoading(true);
    try {
      const rows = await getAnalyticsDetails(category);
      setDetail((current) => current?.category === category ? { ...current, rows } : current);
    } catch (detailRequestError) {
      setDetailError(detailRequestError.message);
    } finally {
      setDetailLoading(false);
    }
  };

  if (error) return <Notice msg={{ type: "error", text: error }} />;
  if (!report) return <p className="text-foreground/70">Loading analytics…</p>;
  const { descriptive: d, diagnostic: g, predictive: p, prescriptive: rx } = report;
  const t = d.totals;
  const empty = t.consultations === 0 && t.applications === 0;
  const detailRows = (detail?.rows || []).filter((row) =>
    Object.values(row).some((value) => String(value ?? "").toLowerCase().includes(detailQuery.toLowerCase()))
  );
  const detailColumns = detailRows[0] ? Object.keys(detailRows[0]) : [];
  const labelFor = (key) => key.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
  const displayValue = (value) => {
    if (value == null || value === "") return "–";
    if (typeof value === "boolean") return value ? "Yes" : "No";
    return String(value);
  };

  const refresh = () => {
    triggerRefreshAnimation();
    load();
  };

  if (detail) {
    return (
      <div className="grid gap-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="grid gap-2">
            <Button variant="ghost" className="w-fit px-0" onClick={() => setDetail(null)}><ArrowLeft /> Back to Analytics</Button>
            <div className="grid gap-1">
              <h1 className="text-3xl font-extrabold tracking-tight">{detail.title}</h1>
              <p className="text-foreground/70">{detail.description}</p>
            </div>
          </div>
          <span className="rounded-full bg-muted px-4 py-2 text-sm font-semibold text-muted-foreground">
            {detailLoading ? "Loading…" : `${detailRows.length} record(s)`}
          </span>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <form className="flex w-full gap-2 sm:max-w-md" onSubmit={(event) => event.preventDefault()}>
            <Input value={detailQuery} onChange={(event) => setDetailQuery(event.target.value)} placeholder="Search these records" />
            <Button type="submit" variant="outline"><Search /> Search</Button>
          </form>
        </div>
        {detailError && <Notice msg={{ type: "error", text: detailError }} />}
        {detailLoading ? (
          <p className="text-sm text-muted-foreground" role="status">Loading records…</p>
        ) : detailRows.length ? (
          <GlassCard className="overflow-hidden">
            <div className="overflow-x-auto p-2">
              <table className="w-full min-w-[48rem] text-left text-sm">
                <thead><tr className="text-xs uppercase tracking-wide text-muted-foreground">
                  {detailColumns.map((column) => <th key={column} className="p-3">{labelFor(column)}</th>)}
                </tr></thead>
                <tbody>
                  {detailRows.map((row, index) => (
                    <tr key={row.user_id || row.application_id || row.booking_id || row.rating_id || row.task_id || row.adviser_id || index} className="border-t border-border/50">
                      {detailColumns.map((column) => (
                        <td key={column} className="max-w-[22rem] whitespace-normal p-3 align-top">
                          {displayValue(row[column])}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </GlassCard>
        ) : (
          <GlassCard className="p-8 text-center text-muted-foreground">No records found for this category.</GlassCard>
        )}
      </div>
    );
  }

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="grid gap-1">
          <h1 className="text-3xl font-extrabold tracking-tight">{isAdmin ? "Analytics" : "Insights"}</h1>
          <p className="text-foreground/70">{isAdmin ? "How the whole system is being used." : "How your advisees and consultations are doing."}</p>
        </div>
        <Button variant="outline" size="sm" onClick={refresh}><RefreshCw /> Refresh</Button>
      </div>
      {empty && (
        <Notice msg={{ type: "ok", text: isAdmin ? "No data yet. To see sample charts, run: python seed_demo_analytics.py (in the backend folder)." : "No data yet. Charts appear once you have advisees and consultations." }} />
      )}

      <Tabs defaultValue="descriptive">
        <TabsList className="h-auto flex-wrap bg-muted text-foreground">
          <TabsTrigger value="descriptive"><span>What Happened</span></TabsTrigger>
          <TabsTrigger value="diagnostic"><span>Why It Happened</span></TabsTrigger>
          <TabsTrigger value="predictive"><span>What Will Happen</span></TabsTrigger>
          <TabsTrigger value="prescriptive"><span>What To Do</span></TabsTrigger>
        </TabsList>

        {/* ---------------- WHAT HAPPENED (SUMMARY) ---------------- */}
        <TabsContent value="descriptive" className="grid gap-5">
          <p className="text-sm text-foreground/70"><b>What happened?</b> A summary of the records so far.</p>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4">
            {isAdmin && <StatTile tone="blue" icon={<Users className="h-5 w-5" />} label="Students" value={t.students} onExpand={() => navigate("/users?role=student&from=analytics")} />}
            {isAdmin && <StatTile tone="purple" icon={<UserCheck className="h-5 w-5" />} label="Advisers" value={t.advisers} onExpand={() => navigate("/users?role=adviser&from=analytics")} />}
            {!isAdmin && <StatTile tone="blue" icon={<UserCheck className="h-5 w-5" />} label="Advisees" value={d.advisers[0] ? d.advisers[0].advisees : 0} onExpand={() => openDetails("advisees", "Advisees", "Students with approved adviser applications.")} />}
            <StatTile tone="orange" icon={<Calendar className="h-5 w-5" />} label="Consultations" value={t.consultations} caption={`${t.completed} completed`} onExpand={() => openDetails("consultations", "Consultations", "Confirmed and completed consultations.")} />
            <StatTile tone="amber" icon={<ClipboardList className="h-5 w-5" />} label="Pending requests" value={t.pending} onExpand={() => openDetails("pending", "Pending requests", "Applications waiting for an adviser decision.")} />
            <StatTile tone="green" icon={<CheckCircle2 className="h-5 w-5" />} label="Acceptance rate" value={d.acceptance_rate == null ? "–" : `${d.acceptance_rate}%`} caption="approved vs declined" onExpand={() => openDetails("acceptance", "Acceptance rate", "Approved and declined applications used to calculate the acceptance rate.")} />
            <StatTile tone="rose" icon={<AlertTriangle className="h-5 w-5" />} label="Cancellation rate" value={d.cancellation_rate == null ? "–" : `${d.cancellation_rate}%`} caption="of all bookings" onExpand={() => openDetails("cancellations", "Cancelled consultations", "Bookings counted in the cancellation rate.")} />
            <StatTile tone="purple" icon={<Star className="h-5 w-5 fill-current" />} label="Avg rating" value={d.avg_rating == null ? "–" : `★ ${d.avg_rating}`} caption={`${d.rating_count} rating(s)`} onExpand={() => openDetails("ratings", "Consultation ratings", `${d.avg_rating ?? "No"} average out of 5 · ${d.rating_count} rating(s).`)} />
          </div>
          <div className="grid items-stretch gap-5 md:grid-cols-2">
            <ChartCard title="Consultations by weekday" description="Which days are busiest" note="Taller bars mean more consultations happen on that day." onExpand={() => openDetails("weekday", "Consultations by weekday", "Individual confirmed and completed consultations.")}><Bars data={d.by_weekday} /></ChartCard>
            <ChartCard title="Consultations by start time" description="Which hours are most popular" note="Shows the start times students pick the most." onExpand={() => openDetails("hour", "Consultations by start time", "Individual consultations grouped by their start time.")}><Bars data={d.by_hour} color={INK} /></ChartCard>
            <ChartCard title="Applications" note="How many applications are waiting, accepted, or declined." onExpand={() => openDetails("applications", "Applications", "Application records grouped in the chart by status.")}><Donut data={d.application_status} /></ChartCard>
            <ChartCard title="Bookings" note="How many consultations are upcoming, finished, or cancelled." onExpand={() => openDetails("bookings", "Bookings", "Consultation booking records grouped by status.")}><Donut data={d.booking_status} /></ChartCard>
            <ChartCard title="Consultation ratings" description="How students rated their consultations" note="More bars on the right (4-5 stars) mean students are happy with their consultations." onExpand={() => openDetails("ratings", "Consultation ratings", "Individual ratings behind the chart.")}><Bars data={d.rating_distribution} color={AMBER} /></ChartCard>
            <ChartCard title="Board tasks" description={`${t.tasks_done} of ${t.tasks} tasks done`} onExpand={() => openDetails("tasks", "Board tasks", "Individual tasks grouped by status.")}><Bars data={d.task_status} color={SAGE} /></ChartCard>
            <ChartCard
              title={isAdmin ? "Adviser workload" : "Your capacity"}
              description="Advisees compared with capacity"
              onExpand={() => openDetails("workload", isAdmin ? "Adviser workload" : "Your capacity", "Adviser advisees, capacity, and consultation activity.")}
            >
              <div className="grid gap-3">
                {d.advisers.length === 0 && <p className="text-sm text-muted-foreground">No advisers yet.</p>}
                {d.advisers.map((a) => (
                  <div key={a.adviser_id} className="grid gap-1">
                    <div className="flex items-center justify-between text-sm"><b>{a.name}</b><span>{a.advisees}/{a.capacity} · {a.utilization}%</span></div>
                    <Progress value={Math.min(a.utilization, 100)} className={a.utilization >= 90 ? "[&>div]:bg-destructive" : ""} />
                    <small className="text-muted-foreground">{a.consultations} consultations · {a.completed} completed · {a.cancelled} cancelled{a.avg_rating ? ` · ★ ${a.avg_rating}` : ""}</small>
                  </div>
                ))}
              </div>
            </ChartCard>
          </div>
        </TabsContent>

        {/* ---------------- WHY IT HAPPENED (DIAGNOSIS) ---------------- */}
        <TabsContent value="diagnostic" className="grid gap-5">
          <p className="text-sm text-foreground/70"><b>Why did it happen?</b> Looks at cancellations to find the cause.</p>
          <div className="grid items-stretch gap-5 md:grid-cols-2">
            <ChartCard title="Who cancels?" description="Cancelled consultations by who cancelled" note="Tells us if students or advisers cancel more often." onExpand={() => openDetails("cancelled_by", "Who cancels?", "Cancelled consultation records, including who cancelled.")}><Donut data={g.cancelled_by} /></ChartCard>
            <ChartCard title="Cancellation rate by weekday" description="Share of bookings cancelled on each day" note="A tall bar means many bookings on that day get cancelled." onExpand={() => openDetails("cancel_weekday", "Cancellation rate by weekday", "Cancelled consultations for each weekday.")}><Bars data={g.cancel_by_weekday.map((r) => ({ name: r.name, value: r.rate }))} color={RED} unit="%" /></ChartCard>
            <GlassCard className="md:col-span-2">
              <CardHeader icon={<AlertTriangle className="h-5 w-5" />} title="What the data says" iconColor="warning" />
              <div className="grid gap-2 p-6 pt-0">
                {g.notes.length === 0 && <p className="text-sm text-muted-foreground">Nothing unusual found.</p>}
                {g.notes.map((n) => <p key={n} className="rounded-xl bg-muted/50 px-3 py-2 text-sm">{n}</p>)}
                <p className="rounded-xl bg-muted/50 px-3 py-2 text-sm"><b>{g.unmarked_past}</b> past consultation(s) were never marked completed.</p>
              </div>
            </GlassCard>
          </div>
        </TabsContent>

        {/* ---------------- WHAT WILL HAPPEN (FORECAST) ---------------- */}
        <TabsContent value="predictive" className="grid gap-5">
          <p className="text-sm text-foreground/70"><b>What will happen?</b> Forecasts from past activity.</p>
          <div className="grid items-stretch gap-5 lg:grid-cols-[2fr_1fr]">
            <ChartCard title="Consultation demand forecast" description="Actual per week, then the next 4 weeks predicted" note="The solid line is what really happened. The dashed line is our estimate for the coming weeks, based on the trend so far." onExpand={() => openDetails("demand", "Consultation demand forecast", "Weekly actual consultation counts and forecast values.", p.demand.series.map((item) => ({ week: item.week, actual: item.actual, forecast: item.forecast })))}>
              <ResponsiveContainer width="100%" height={260}>
                <LineChart data={p.demand.series} margin={{ top: 8, right: 12, left: -18, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
                  <XAxis dataKey="week" tick={tick} tickLine={false} axisLine={false} />
                  <YAxis tick={tick} tickLine={false} axisLine={false} allowDecimals={false} />
                  <Tooltip {...tip} />
                  <Legend iconType="circle" wrapperStyle={{ fontSize: 12, color: INK }} />
                  <Line type="monotone" dataKey="actual" name="Actual" stroke={INK} strokeWidth={3} dot={{ r: 3 }} connectNulls />
                  <Line type="monotone" dataKey="forecast" name="Forecast" stroke={ORANGE} strokeWidth={3} strokeDasharray="6 5" dot={{ r: 3 }} connectNulls />
                </LineChart>
              </ResponsiveContainer>
            </ChartCard>
            <GlassCard className="p-6">
              <div className="flex items-start justify-between gap-2">
                <CardHeader icon={<TrendingUp className="h-5 w-5" />} title="Model summary" iconColor="primary" />
                <Button variant="outline" size="sm" className="shrink-0" onClick={() => openDetails("model-summary", "Model summary", "Forecast statistics and backtest accuracy.", [
                  { metric: "Expected next week", value: p.demand.next_week },
                  { metric: "Trend", value: `${p.demand.trend} (${p.demand.slope > 0 ? "+" : ""}${p.demand.slope} per week)` },
                  { metric: "Fit (R²)", value: p.demand.r2 },
                  { metric: "Model accuracy", value: p.demand.mae == null ? "Not enough weeks yet" : `Off by about ${p.demand.mae} per week` },
                  { metric: "Weeks tested", value: p.demand.tested_weeks },
                ])}>View records</Button>
              </div>
              <div className="mt-3 grid gap-3 text-sm">
                <div><small className="text-muted-foreground">Expected next week</small><p className="text-3xl font-extrabold">{p.demand.next_week}</p></div>
                <div><small className="text-muted-foreground">Trend</small><p className="font-bold capitalize">{p.demand.trend} ({p.demand.slope > 0 ? "+" : ""}{p.demand.slope} per week)</p></div>
                <div><small className="text-muted-foreground">Fit (R²)</small><p className="font-bold">{p.demand.r2}</p></div>
                <div>
                  <small className="text-muted-foreground">Model accuracy (backtest)</small>
                  {p.demand.mae == null
                    ? <p className="font-bold">Not enough weeks yet</p>
                    : <p className="font-bold">Off by about {p.demand.mae} per week <span className="font-normal text-muted-foreground">(guessing "same as last week" is off by {p.demand.naive_mae})</span></p>}
                  <small className="text-muted-foreground">Tested on {p.demand.tested_weeks} past week(s): predicted each week using only earlier weeks.</small>
                </div>
                <p className="text-xs text-muted-foreground">{p.demand.method}.</p>
              </div>
            </GlassCard>
          </div>
          <GlassCard>
            <div className="flex items-start justify-between gap-2">
              <CardHeader icon={<Target className="h-5 w-5" />} title="Advisee progress and risk" description="Risk is predicted from task velocity and recent activity. ETA assumes the same pace continues." iconColor="primary" />
              <Button variant="outline" size="sm" className="shrink-0" onClick={() => openDetails("progress", "Advisee progress and risk", "Progress and risk estimates for each approved advisee.", p.advisees)}>View records</Button>
            </div>
            <div className="overflow-x-auto p-6 pt-0">
              {p.advisees.length === 0 && <p className="text-sm text-muted-foreground">No approved advisees yet.</p>}
              {p.advisees.length > 0 && (
                <table className="w-full min-w-[40rem] text-left text-sm">
                  <thead><tr className="text-xs uppercase tracking-wide text-muted-foreground">
                    <th className="pb-2">Student</th>{isAdmin && <th className="pb-2">Adviser</th>}<th className="pb-2">Progress</th><th className="pb-2">Pace</th><th className="pb-2">Inactive</th><th className="pb-2">Est. finish</th><th className="pb-2">Risk</th>
                  </tr></thead>
                  <tbody>
                    {p.advisees.map((a) => (
                      <tr key={a.application_id} className="border-t border-border/50">
                        <td className="py-2.5 font-semibold">{a.student}</td>
                        {isAdmin && <td>{a.adviser}</td>}
                        <td className="w-44 pr-4"><Progress value={a.progress} className="h-2" /><small className="text-muted-foreground">{a.done}/{a.total} tasks</small></td>
                        <td>{a.velocity}/wk</td>
                        <td>{a.days_inactive == null ? "–" : `${a.days_inactive} d`}</td>
                        <td>{a.eta || "–"}</td>
                        <td><StatusPill tone={RISK[a.risk]}>{a.risk}</StatusPill></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </GlassCard>
        </TabsContent>

        {/* ---------------- WHAT TO DO (ACTIONS) ---------------- */}
        <TabsContent value="prescriptive" className="grid gap-4">
          <p className="text-sm text-foreground/70"><b>What should we do?</b> Suggested actions based on all of the above.</p>
          <div className="grid gap-3 md:grid-cols-2">
            {rx.map((r, i) => {
              const [Icon, cls] = REC[r.level] || REC.info;
              return (
                <GlassCard key={i} className="flex items-start gap-3 p-4">
                  <span className={cn("grid h-9 w-9 shrink-0 place-items-center rounded-full", cls)}><Icon className="h-4 w-4" /></span>
                  <p className="text-sm font-medium leading-snug">{r.text}</p>
                </GlassCard>
              );
            })}
          </div>
        </TabsContent>
      </Tabs>
    </>
  );
}