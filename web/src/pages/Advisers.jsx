import { useEffect, useState } from "react";
import { ArrowLeft, Building2, GraduationCap, Search, Sparkles, Star, Clock, Users } from "lucide-react";
import { useOutletContext } from "react-router-dom";
import { applyTo, listAdvisers, withdrawApplication } from "@/api";
import { StudentWaitlist, AdviserWaitlistView } from "@/components/Waitlist";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { GlassCard, CardHeader, StatusPill, PersonChip, EmptyState, InfoRow, StatTile } from "@/components/ui/bento";
import { AlertDialog, AlertDialogContent, AlertDialogHeader, AlertDialogTitle, AlertDialogDescription, AlertDialogFooter, AlertDialogAction, AlertDialogCancel } from "@/components/ui/alert-dialog";

const STEPS = [
  ["1", "Find an adviser", "Search by topic, skill, or name."],
  ["2", "Send your application", "Describe your thesis or capstone topic."],
  ["3", "Book and track", "Once approved, schedule consultations and use your progress board."],
];

function AdviserCard({ adviser, bestMatch, onApply, canApply }) {
  const { tags, matched, avg_rating, rating_count, certifications, slots_left, max_capacity } = adviser;
  const isFull = slots_left === 0;
  const adviserName = adviser.name || "Adviser";

  return (
    <GlassCard className="flex flex-col h-full">
      <div className="mb-4 flex flex-row items-start justify-between gap-2 pb-2">
        <div>
          <div className="flex items-center gap-2">
            {adviser.profile_photo ? (
              <img src={adviser.profile_photo} alt="" className="h-10 w-10 shrink-0 rounded-full object-cover" />
            ) : (
              <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/20 font-bold text-primary">{adviserName.charAt(0).toUpperCase()}</span>
            )}
            <h3 className="text-lg font-semibold truncate">{adviserName}</h3>
          </div>
          {bestMatch && <small className="font-bold text-primary">Best match for your topic</small>}
        </div>
        {adviser.match != null && (
          <StatusPill tone={bestMatch ? "primary" : "default"} leadingIcon={bestMatch ? <Sparkles className="h-3 w-3" /> : null}>
            {adviser.match}% match
          </StatusPill>
        )}
      </div>
      <div className="grid content-start gap-3 flex-1">
        <div className="flex flex-wrap gap-1.5">
          {tags.length ? tags.map((t) => (
            <StatusPill key={t} tone={(matched || []).some((m) => t.toLowerCase().includes(m)) ? "primary" : "default"} variant="outline" size="sm">
              {t}
            </StatusPill>
          )) : <span className="text-sm text-muted-foreground">No specializations listed yet</span>}
        </div>
        <InfoRow icon={<Star className="h-3.5 w-3.5" />} label="Rating" value={avg_rating ? `${avg_rating} (${rating_count} rating${rating_count > 1 ? "s" : ""})` : "No ratings yet"} iconColor={avg_rating ? "primary" : "muted"} />
        {certifications && <InfoRow icon={<GraduationCap className="h-3.5 w-3.5" />} label="Certifications" value={certifications} iconColor="muted" />}
        <InfoRow icon={<Clock className="h-3.5 w-3.5" />} label="Availability" value={isFull ? "Full" : `${slots_left} of ${max_capacity} slots open`} iconColor={isFull ? "destructive" : "success"} />
      </div>
      <div className="pt-2 border-t border-border/30">
        <Button className="w-full" disabled={isFull || !canApply} onClick={() => onApply(adviser)}>
          {isFull ? "Full" : canApply ? "Apply" : "Leader accounts only"}
        </Button>
      </div>
    </GlassCard>
  );
}

function StepCard({ step, title, description }) {
  return (
    <GlassCard className="p-5">
      <div className="flex items-start gap-3">
        <span className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-primary text-sm font-extrabold text-primary-foreground">{step}</span>
        <div>
          <b className="mt-1 block">{title}</b>
          <span className="text-sm text-muted-foreground">{description}</span>
        </div>
      </div>
    </GlassCard>
  );
}

function PendingCard({ app, refresh, onMessage }) {
  const [open, setOpen] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);

  async function confirmWithdraw() {
    setWithdrawing(true);
    try {
      await withdrawApplication(app.application_id);
      setOpen(false);
      onMessage({ type: "ok", text: "Application withdrawn." });
      refresh();
    } catch (err) {
      onMessage({ type: "error", text: err.message });
    } finally {
      setWithdrawing(false);
    }
  }

  return (
    <>
      <GlassCard className="max-w-2xl">
        <CardHeader className="flex flex-row items-center justify-between gap-2">
          <div className="flex items-center gap-2 min-w-0">
            {app.adviser_profile_photo ? (
              <img src={app.adviser_profile_photo} alt="" className="h-9 w-9 shrink-0 rounded-full object-cover" />
            ) : (
              <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/20 font-bold text-primary">{app.adviser_name.charAt(0).toUpperCase()}</span>
            )}
            <h3 className="truncate text-xl font-semibold">{app.adviser_name}</h3>
          </div>
          <StatusPill tone="warning">pending</StatusPill>
        </CardHeader>
        <div className="p-4 pt-0">
          <p className="text-sm text-muted-foreground">Your topic</p>
          <p>{app.topic_brief}</p>
        </div>
        <div className="p-4 pt-0 border-t border-border/30">
          <Button variant="destructive" onClick={() => setOpen(true)}>Withdraw application</Button>
        </div>
      </GlassCard>

      <AlertDialog open={open} onOpenChange={setOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Withdraw application?</AlertDialogTitle>
            <AlertDialogDescription>
              This will cancel your application to <strong>{app.adviser_name}</strong>. You can apply again later.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={confirmWithdraw} disabled={withdrawing} variant="destructive">
              {withdrawing ? "Withdrawing…" : "Withdraw"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

export default function Advisers() {
  const { status, refresh, user } = useOutletContext();
  const app = status.application;
  const pending = app && app.status === "pending";
  const canApply = user?.student_group_role !== "member";
  const [q, setQ] = useState("");
  const [list, setList] = useState([]);
  const [selectedDepartment, setSelectedDepartment] = useState(null);
  const [applying, setApplying] = useState(null);
  const [brief, setBrief] = useState("");
  const [msg, setMsg] = useState({ type: "", text: "" });

  const load = (query = q) => listAdvisers(query).then(setList).catch((e) => setMsg({ type: "error", text: e.message }));
  useEffect(() => { if (!pending) load(""); }, [pending]);
  const departmentOf = (adviser) => adviser.tags?.find((tag) => /^Department:\s*/i.test(tag))?.replace(/^Department:\s*/i, "").trim() || "Other departments";
  const departments = [...new Set(list.map(departmentOf))].sort((a, b) => a.localeCompare(b));
  const advisersInDepartment = selectedDepartment
    ? list.filter((adviser) => departmentOf(adviser) === selectedDepartment)
    : [];
  const searching = Boolean(q.trim());

  async function submitApply(e) {
    e.preventDefault();
    try {
      await applyTo({ adviser_id: applying.adviser_id, topic_brief: brief });
      setApplying(null); setBrief("");
      setMsg({ type: "ok", text: "Application sent. You'll be notified when the adviser replies." });
      refresh();
    } catch (err) { setMsg({ type: "error", text: err.message }); }
  }

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">{pending ? "Your application" : "Find your adviser"}</h1>
        <p className="text-foreground/70">{pending ? "Waiting for your adviser to reply." : "Describe your topic in your own words. We match it to each adviser's specializations and show the best fit first."}</p>
      </div>
      <Notice msg={msg} />
        {user?.role === "student" && !canApply && (
          <div className="rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm">
            Only student group leader accounts can apply to an adviser. Group member accounts can join an approved group through an invitation or request.
          </div>
        )}

      {!app && (
        <div className="grid gap-3 md:grid-cols-3">
          {STEPS.map(([n, title, text]) => (
            <StepCard key={n} step={n} title={title} description={text} />
          ))}
        </div>
      )}

      {pending && <PendingCard app={app} refresh={refresh} onMessage={setMsg} />}

      {app && app.status === "declined" && (
        <div className="rounded-xl bg-destructive/10 border border-destructive/20 p-4">
          <p className="text-destructive font-medium">{app.adviser_name} declined your application. You can choose another adviser below.</p>
        </div>
      )}

      {!pending && (
        <Tabs defaultValue="find" className="w-full">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="find"><span className="flex items-center gap-1"><Search className="h-4 w-4" /> Find Adviser</span></TabsTrigger>
            <TabsTrigger value="waitlist"><span className="flex items-center gap-1"><Clock className="h-4 w-4" /> My Waitlist</span></TabsTrigger>
          </TabsList>

          <TabsContent value="find">
            <form className="flex gap-2" onSubmit={(e) => { e.preventDefault(); setSelectedDepartment(null); load(q); }}>
              <Input className="flex-1" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search by adviser, department, or specialization" />
              <Button type="submit"><Search /> Search</Button>
            </form>
            {list.length === 0 && searching && (
              <EmptyState
                icon={<Search className="h-12 w-12" />}
                title="No advisers matched"
                description="Try a different keyword or broader topic."
                action={() => { setQ(""); load(""); }}
                actionLabel="Show all advisers"
              />
            )}
            {list.length === 0 && !searching && (
              <EmptyState
                icon={<GraduationCap className="h-12 w-12" />}
                title="No departments available"
                description="Approved advisers will appear here when their profiles are ready."
              />
            )}
            {!searching && !selectedDepartment && departments.length > 0 && (
              <>
                <div className="mt-5 flex items-center justify-between gap-3">
                  <div>
                    <h2 className="text-xl font-bold">Browse by department</h2>
                    <p className="text-sm text-muted-foreground">Choose a department to view its advisers.</p>
                  </div>
                  <span className="text-sm text-muted-foreground">{departments.length} departments</span>
                </div>
                <div className="mt-4 grid items-stretch gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  {departments.map((department) => {
                    const count = list.filter((adviser) => departmentOf(adviser) === department).length;
                    return (
                      <button key={department} type="button" onClick={() => setSelectedDepartment(department)} className="text-left">
                        <GlassCard hover className="h-full">
                          <div className="flex items-center gap-3">
                            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-primary/10 text-primary"><Building2 className="h-5 w-5" /></span>
                            <div className="min-w-0 flex-1">
                              <h3 className="font-semibold">{department}</h3>
                              <p className="mt-1 flex items-center gap-1 text-sm text-muted-foreground"><Users className="h-3.5 w-3.5" />{count} adviser{count === 1 ? "" : "s"}</p>
                            </div>
                          </div>
                        </GlassCard>
                      </button>
                    );
                  })}
                </div>
              </>
            )}
            {(searching || selectedDepartment) && (
              <>
                {selectedDepartment && (
                  <div className="mt-5 flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <h2 className="text-xl font-bold">{selectedDepartment}</h2>
                      <p className="text-sm text-muted-foreground">{advisersInDepartment.length} adviser{advisersInDepartment.length === 1 ? "" : "s"}</p>
                    </div>
                    <Button type="button" variant="outline" onClick={() => setSelectedDepartment(null)}><ArrowLeft className="h-4 w-4" /> All departments</Button>
                  </div>
                )}
                <div className="mt-4 grid items-stretch gap-4 md:grid-cols-2 lg:grid-cols-3">
                  {(selectedDepartment ? advisersInDepartment : list).map((a) => (
                    <AdviserCard key={a.adviser_id} adviser={a} bestMatch={a.best_match} canApply={canApply} onApply={(adviser) => { setApplying(adviser); setBrief(user.thesis_title || ""); }} />
                  ))}
                </div>
              </>
            )}
          </TabsContent>

          <TabsContent value="waitlist">
            <StudentWaitlist onRefresh={load} />
          </TabsContent>
        </Tabs>
      )}

      {/* Adviser Waitlist View */}
      {user?.role === "adviser" && !pending && (
        <Tabs defaultValue="waitlist" className="w-full">
          <TabsList>
            <TabsTrigger value="waitlist"><span className="flex items-center gap-1"><Clock className="h-4 w-4" /> Waitlist</span></TabsTrigger>
          </TabsList>
          <TabsContent value="waitlist">
            <AdviserWaitlistView onRefresh={load} />
          </TabsContent>
        </Tabs>
      )}

      <Dialog open={Boolean(applying)} onOpenChange={(o) => !o && setApplying(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Apply to {applying && applying.name}</DialogTitle>
            <DialogDescription>Tell them what your thesis or capstone is about.</DialogDescription>
          </DialogHeader>
          <form onSubmit={submitApply} className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="brief">Topic</Label>
              <Textarea id="brief" value={brief} onChange={(e) => setBrief(e.target.value)} rows={5} minLength={10} maxLength={2000} required />
            </div>
            <Button type="submit">Send application</Button>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}