import { useCallback, useEffect, useState } from "react";
import { useOutletContext, useSearchParams } from "react-router-dom";
import { Calendar, ChevronDown, ChevronUp, Edit, Loader2, Plus, Trash2, X, Target, CheckCircle2, Clock, AlertTriangle } from "lucide-react";
import { getMilestones, createMilestone, updateMilestone, deleteMilestone, myApplications } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { cn } from "@/lib/utils";
import { parseISO, format } from "date-fns";
import { Calendar as CalendarComp } from "@/components/ui/calendar";
import { GlassCard, CardHeader, StatusPill, StatTile, ProgressBarWithTicks, EmptyState, InfoRow, PersonChip } from "@/components/ui/bento";

const STAGE_LABELS = {
  title_defense: "Title Defense",
  chapters_1_3: "Chapters 1-3",
  proposal_defense: "Proposal Defense",
  final_defense: "Final Defense",
  custom: "Custom",
};

const STATUS_LABELS = {
  pending: "Pending",
  in_progress: "In Progress",
  completed: "Completed",
  overdue: "Overdue",
};

const STATUS_TONES = {
  pending: "warning",
  in_progress: "info",
  completed: "success",
  overdue: "error",
};

const STATUS_CARD_CLASSES = {
  pending: "border-amber-300/70 bg-amber-50/60 dark:border-amber-800/50 dark:bg-amber-950/20",
  in_progress: "border-blue-300/70 bg-blue-50/60 dark:border-blue-800/50 dark:bg-blue-950/20",
  completed: "border-green-300/70 bg-green-50/60 dark:border-green-800/50 dark:bg-green-950/20",
  overdue: "border-red-300/70 bg-red-50/60 dark:border-red-800/50 dark:bg-red-950/20",
};

function isMilestoneOverdue(milestone) {
  if (!milestone.due_date || milestone.status === "completed") return false;
  const due = new Date(`${milestone.due_date.slice(0, 10)}T00:00:00`);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return due < today;
}

function effectiveMilestoneStatus(milestone) {
  return isMilestoneOverdue(milestone) ? "overdue" : milestone.status;
}

function MilestoneCard({ milestone, isAdviser, onEdit, onDelete, loadingId }) {
  const effectiveStatus = effectiveMilestoneStatus(milestone);
  const statusTone = STATUS_TONES[effectiveStatus] || "default";

  return (
    <GlassCard className={cn("relative border", STATUS_CARD_CLASSES[effectiveStatus])}>
      <div className="flex items-start justify-between gap-2 p-4 pt-4 pb-2">
        <div className="flex-1 min-w-0">
          <h3 className="text-lg font-semibold truncate">{milestone.title}</h3>
          <div className="flex flex-wrap items-center gap-2 mt-2">
            <StatusPill tone={statusTone}>{STATUS_LABELS[effectiveStatus]}</StatusPill>
            <StatusPill tone="default" variant="outline">{STAGE_LABELS[milestone.stage] || milestone.stage}</StatusPill>
            {milestone.due_date && (
              <StatusPill tone={statusTone} leadingIcon={<Calendar className="h-3 w-3" />}>
                {format(parseISO(milestone.due_date), "MMM d, yyyy")}
              </StatusPill>
            )}
          </div>
        </div>
        {isAdviser && (
          <div className="flex gap-1">
            <button
              type="button"
              onClick={() => onEdit(milestone)}
              disabled={loadingId === milestone.milestone_id}
              aria-label="Edit"
              className="p-2 rounded-full text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
            >
              {loadingId === milestone.milestone_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Edit className="h-4 w-4" />}
            </button>
            <button
              type="button"
              onClick={() => onDelete(milestone)}
              disabled={loadingId === milestone.milestone_id}
              aria-label="Delete"
              className="p-2 rounded-full text-muted-foreground hover:bg-destructive/10 hover:text-destructive transition-colors"
            >
              {loadingId === milestone.milestone_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
            </button>
          </div>
        )}
      </div>
      <div className="px-4 pb-4 grid gap-3">
        {milestone.description && <p className="text-sm text-muted-foreground">{milestone.description}</p>}
        <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
          <span>Created by {milestone.created_by_name}</span>
          <span>·</span>
          <span>{format(parseISO(milestone.created_at), "MMM d, yyyy")}</span>
          {milestone.updated_at !== milestone.created_at && (
            <>
              <span>·</span>
              <span>Updated {format(parseISO(milestone.updated_at), "MMM d, yyyy")}</span>
            </>
          )}
          {milestone.completed_date && (
            <>
              <span>·</span>
              <span className="text-success">Completed {format(parseISO(milestone.completed_date), "MMM d, yyyy")}</span>
            </>
          )}
        </div>
      </div>
    </GlassCard>
  );
}

function MilestoneForm({ milestone, onSubmit, onCancel, loading }) {
  const [form, setForm] = useState({
    title: milestone?.title || "",
    description: milestone?.description || "",
    stage: milestone?.stage || "title_defense",
    due_date: milestone?.due_date || "",
    status: milestone?.status || "pending",
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit(form);
  };

  return (
    <GlassCard className="max-w-2xl">
      <CardHeader title={milestone ? "Edit Milestone" : "New Milestone"} description={milestone ? "Update the milestone details below." : "Add a new milestone to track progress."} />
      <form onSubmit={handleSubmit} className="grid gap-4 p-4 pt-0">
        <div className="grid gap-1.5">
          <Label htmlFor="title">Title *</Label>
          <Input id="title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} required maxLength={150} placeholder="e.g. Submit Chapter 1 Draft" />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="description">Description</Label>
          <Textarea id="description" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} rows={3} maxLength={2000} placeholder="Optional details…" />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="stage">Stage *</Label>
          <Select id="stage" value={form.stage} onChange={(e) => setForm({ ...form, stage: e.target.value })} required>
            <option value="title_defense">Title Defense</option>
            <option value="chapters_1_3">Chapters 1-3</option>
            <option value="proposal_defense">Proposal Defense</option>
            <option value="final_defense">Final Defense</option>
            <option value="custom">Custom</option>
          </Select>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="due_date">Due Date</Label>
          <Popover>
            <PopoverTrigger asChild>
              <Input
                id="due_date"
                type="text"
                readOnly
                value={form.due_date ? format(parseISO(form.due_date), "MMM d, yyyy") : ""}
                placeholder="Pick a date"
              />
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="start">
              <CalendarComp
                mode="single"
                selected={form.due_date ? parseISO(form.due_date) : undefined}
                onSelect={(d) => setForm({ ...form, due_date: d ? format(d, "yyyy-MM-dd") : "" })}
                initialFocus
              />
            </PopoverContent>
          </Popover>
        </div>
        {milestone && (
          <div className="grid gap-1.5">
            <Label htmlFor="status">Status</Label>
            <Select id="status" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
              <option value="pending">Pending</option>
              <option value="in_progress">In Progress</option>
              <option value="completed">Completed</option>
              <option value="overdue">Overdue</option>
            </Select>
          </div>
        )}
        <div className="flex gap-2 pt-2">
          <Button type="submit" disabled={loading}>
            {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : null}
            {milestone ? "Save Changes" : "Create Milestone"}
          </Button>
          <Button type="button" variant="outline" onClick={onCancel}>Cancel</Button>
        </div>
      </form>
    </GlassCard>
  );
}

export default function Milestones() {
  const { user, status } = useOutletContext();
  const isAdviser = user.role === "adviser";
  const [params, setParams] = useSearchParams();
  const [apps, setApps] = useState([]);
  const [milestones, setMilestones] = useState([]);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [deleting, setDeleting] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    myApplications()
      .then(data => {
        const ok = data.filter(a => a.status === "approved");
        setApps(ok);
        if (!params.get("app") && ok.length) setParams({ app: String(ok[0].application_id) }, { replace: true });
      })
      .catch(e => setMsg({ type: "error", text: e.message }));
  }, []);

  const appId = params.get("app");
  const load = useCallback(async () => {
    if (!appId) return;
    try {
      const data = await getMilestones(appId);
      setMilestones(data);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
  }, [appId]);
  useEffect(() => { load(); }, [load]);

  const run = async (fn, okText) => {
    setLoading(true);
    setMsg({ type: "", text: "" });
    try {
      await fn();
      if (okText) setMsg({ type: "ok", text: okText });
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = (data) => run(() => createMilestone(appId, data), "Milestone created.");
  const handleUpdate = (data) => run(() => updateMilestone(editing.milestone_id, data), "Milestone updated.");
  const handleDelete = () => run(() => deleteMilestone(deleting.milestone_id), "Milestone deleted.");

  const submitForm = async (data) => {
    if (editing) {
      await handleUpdate({
        title: data.title,
        description: data.description || null,
        stage: data.stage,
        due_date: data.due_date || null,
        status: data.status,
      });
    } else {
      await handleCreate({
        title: data.title,
        description: data.description || null,
        stage: data.stage,
        due_date: data.due_date || null,
      });
    }
    setShowForm(false);
    setEditing(null);
  };

  if (apps.length === 0) {
    return (
      <>
        <h1 className="text-3xl font-extrabold tracking-tight">Milestones</h1>
        <p className="text-foreground/70">Milestones appear once an application is approved.</p>
      </>
    );
  }

  const currentApp = apps.find(a => a.application_id === Number(appId));
  const pendingCount = milestones.filter(m => effectiveMilestoneStatus(m) === "pending").length;
  const inProgressCount = milestones.filter(m => effectiveMilestoneStatus(m) === "in_progress").length;
  const completedCount = milestones.filter(m => m.status === "completed").length;
  const overdueCount = milestones.filter(m => effectiveMilestoneStatus(m) === "overdue").length;
  const total = milestones.length;
  const done = completedCount;
  const progress = total > 0 ? Math.round((done / total) * 100) : 0;

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Milestones</h1>
        {apps.length > 1 ? (
          <div className="flex flex-wrap items-center gap-2">
            <Select value={appId || ""} onChange={(e) => setParams({ app: e.target.value })} className="w-auto max-w-xs">
              {apps.map(a => <option key={a.application_id} value={a.application_id}>{isAdviser ? a.student_name : a.adviser_name}</option>)}
            </Select>
          </div>
        ) : null}
        {currentApp && (
          <PersonChip
            avatar={isAdviser ? currentApp.student_profile_photo : currentApp.adviser_profile_photo}
            name={isAdviser ? currentApp.student_name : currentApp.adviser_name}
            subtitle={currentApp.topic_brief}
          />
        )}
      </div>
      <Notice msg={msg} />

      {/* Progress Overview */}
      <GlassCard>
        <CardHeader icon={<Target className="h-5 w-5" />} title="Overall Progress" description={`${done} of ${total} milestones completed`} iconColor="primary" />
        <div className="grid gap-4 p-4 pt-0">
          <ProgressBarWithTicks value={progress} total={total} completed={done} showLabels />
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <StatTile tone="green" icon={<CheckCircle2 className="h-5 w-5" />} label="Completed" value={completedCount} />
            <StatTile tone="blue" icon={<Loader2 className="h-5 w-5" />} label="In Progress" value={inProgressCount} />
            <StatTile tone="amber" icon={<Clock className="h-5 w-5" />} label="Pending" value={pendingCount} />
            <StatTile tone="rose" icon={<AlertTriangle className="h-5 w-5" />} label="Overdue" value={overdueCount} />
          </div>
        </div>
      </GlassCard>

      <div className="grid gap-4 md:grid-cols-[1fr_380px]">
        <div className="grid gap-4">
          {isAdviser && (
            <Button onClick={() => { setEditing(null); setShowForm(true); }} className="w-full sm:w-auto"><Plus className="h-4 w-4 mr-2" /> Add Milestone</Button>
          )}
          {milestones.length === 0 ? (
            <EmptyState
              icon={<Target className="h-12 w-12" />}
              title="No milestones yet"
              description={isAdviser ? "Create one to track progress." : "Your adviser will add milestones."}
              action={isAdviser ? { label: "Add Milestone", onClick: () => { setEditing(null); setShowForm(true); }} : null}
            />
          ) : (
            milestones.map(m => (
              <MilestoneCard
                key={m.milestone_id}
                milestone={m}
                isAdviser={isAdviser}
                onEdit={(m) => { setEditing(m); setShowForm(true); }}
                onDelete={(m) => { setDeleting(m); }}
                loadingId={loading && (editing?.milestone_id === m.milestone_id || deleting?.milestone_id === m.milestone_id) ? m.milestone_id : null}
              />
            ))
          )}
        </div>

        {showForm && (
          <div className="sticky top-24">
            <MilestoneForm
              milestone={editing}
              onSubmit={submitForm}
              onCancel={() => { setShowForm(false); setEditing(null); }}
              loading={loading}
            />
          </div>
        )}

        {deleting && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
            <GlassCard className="w-full max-w-md p-6">
              <h3 className="text-lg font-semibold">Delete Milestone</h3>
              <p className="text-sm text-muted-foreground mt-1">Are you sure you want to delete "{deleting.title}"? This cannot be undone.</p>
              <div className="flex gap-2 justify-end mt-4">
                <Button variant="outline" onClick={() => setDeleting(null)}>Cancel</Button>
                <Button variant="destructive" onClick={handleDelete} disabled={loading}>
                  {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : "Delete"}
                </Button>
              </div>
            </GlassCard>
          </div>
        )}
      </div>
    </>
  );
}