import { useCallback, useEffect, useState } from "react";
import { AlertCircle, Bell, Loader2, Plus, X, XCircle } from "lucide-react";
import { joinWaitlist, myWaitlist, adviserWaitlist, notifyWaitlist, cancelWaitlist } from "@/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { format } from "date-fns";

function WaitlistItem({ item, role, onNotify, onCancel, loadingId }) {
  const isWaiting = item.status === "waiting";
  const isNotified = item.status === "notified";
  const isExpired = item.status === "expired";

  return (
    <Card className="p-3 flex items-center justify-between gap-3">
      <div className="flex items-center gap-3 min-w-0 flex-1">
        <div className={cn("flex items-center justify-center w-10 h-10 rounded-lg font-bold", isWaiting ? "bg-primary/10 text-primary" : isNotified ? "bg-success/10 text-success" : "bg-muted text-muted-foreground")}>
          #{item.position}
        </div>
        <div className="flex min-w-0 items-center gap-2">
          {(role === "student" ? item.adviser_profile_photo : item.student_profile_photo) ? (
            <img src={role === "student" ? item.adviser_profile_photo : item.student_profile_photo} alt="" className="h-9 w-9 shrink-0 rounded-full object-cover" />
          ) : (
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/20 text-sm font-bold text-primary">
              {(role === "student" ? item.adviser_name : item.student_name)?.charAt(0).toUpperCase() || "?"}
            </span>
          )}
          <div className="min-w-0">
          <p className="font-medium truncate">{role === "student" ? item.adviser_name : item.student_name}</p>
          <p className="text-sm text-muted-foreground truncate">{item.topic_brief}</p>
          <div className="flex flex-wrap items-center gap-2 mt-1 text-xs">
            <Badge variant={isWaiting ? "default" : isNotified ? "success" : "destructive"}>{item.status}</Badge>
            {item.expires_at && (
              <Badge variant="outline">
                <AlertCircle className="h-3 w-3 mr-1" />
                Expires {format(new Date(item.expires_at), "MMM d, yyyy")}
              </Badge>
            )}
            {role === "student" && item.notified_at && (
              <Badge variant="outline">
                <Bell className="h-3 w-3 mr-1" />
                Notified {format(new Date(item.notified_at), "MMM d, yyyy HH:mm")}
              </Badge>
            )}
            {role === "adviser" && item.student_email && (
              <span className="text-muted-foreground">{item.student_email}</span>
            )}
          </div>
          </div>
        </div>
      </div>
      <div className="flex gap-1 shrink-0">
        {role === "adviser" && isWaiting && (
          <Button variant="outline" size="sm" onClick={() => onNotify(item.waitlist_id)} disabled={loadingId === item.waitlist_id}>
            {loadingId === item.waitlist_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <> <Bell className="h-4 w-4 mr-1" /> Notify </>}
          </Button>
        )}
        {((role === "student" && isWaiting) || (role === "adviser" && isWaiting)) && (
          <Button variant="ghost" size="icon" className="text-destructive" onClick={() => onCancel(item.waitlist_id)} disabled={loadingId === item.waitlist_id} aria-label="Cancel">
            {loadingId === item.waitlist_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <XCircle className="h-4 w-4" />}
          </Button>
        )}
      </div>
    </Card>
  );
}

export function StudentWaitlist({ onRefresh }) {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ adviser_id: "", topic_brief: "" });
  const [advisers, setAdvisers] = useState([]);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [loadingId, setLoadingId] = useState(null);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    try {
      const [myWaitlistData, advisersData] = await Promise.all([
        myWaitlist(),
        fetch("/api/advisers?").then(r => r.json()),
      ]);
      setEntries(myWaitlistData);
      setAdvisers(advisersData.filter(a => a.slots_left === 0)); // Only full advisers
    } catch (e) {
      setError(e.message);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setMsg({ type: "", text: "" });
    try {
      await joinWaitlist(form);
      setMsg({ type: "ok", text: "Added to waitlist." });
      setShowForm(false);
      setForm({ adviser_id: "", topic_brief: "" });
      load();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  };

  const handleNotify = async (id) => {
    setLoadingId(id);
    try {
      await notifyWaitlist(id); // This is for adviser, but keeping for consistency
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  const handleCancel = async (id) => {
    setLoadingId(id);
    try {
      await cancelWaitlist(id);
      setMsg({ type: "ok", text: "Waitlist entry cancelled." });
      load();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  return (
    <div className="grid gap-4">
      <div className="flex items-center justify-between">
        <CardTitle className="text-lg">My Waitlist</CardTitle>
        <Button onClick={() => setShowForm(true)} disabled={advisers.length === 0}>
          <Plus className="h-4 w-4 mr-2" /> Join Waitlist
        </Button>
      </div>

      <Notice msg={msg} />

      {showForm && (
        <Card className="p-4 border-primary/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Join Waitlist</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3">
            <form onSubmit={handleSubmit} className="grid gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="wl-adviser">Adviser *</Label>
                <select
                  id="wl-adviser"
                  value={form.adviser_id}
                  onChange={(e) => setForm({ ...form, adviser_id: e.target.value })}
                  required
                  className="rounded-md border border-input bg-background px-3 py-2 text-sm"
                >
                  <option value="">Select an adviser with no open slots</option>
                  {advisers.map(a => (
                    <option key={a.adviser_id} value={a.adviser_id}>
                      {a.name} (Full: {a.max_capacity}/{a.max_capacity})
                    </option>
                  ))}
                </select>
                {advisers.length === 0 && <p className="text-sm text-muted-foreground">No advisers are currently full.</p>}
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="wl-topic">Topic Brief *</Label>
                <Textarea id="wl-topic" value={form.topic_brief} onChange={(e) => setForm({ ...form, topic_brief: e.target.value })} rows={3} minLength={10} maxLength={2000} required placeholder="Describe your thesis/capstone topic…" />
              </div>
              <div className="flex gap-2">
                <Button type="submit" disabled={loading || !form.adviser_id}>
                  {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : "Join Waitlist"}
                </Button>
                <Button type="button" variant="outline" onClick={() => { setShowForm(false); setForm({ adviser_id: "", topic_brief: "" }); }}>
                  <X className="h-4 w-4 mr-1" /> Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {entries.length === 0 ? (
        <Card className="p-8 text-center border-dashed">
          <p className="text-muted-foreground">You're not on any waitlists.</p>
          <p className="text-sm text-muted-foreground mt-1">Join a waitlist for a full adviser to be notified when a slot opens.</p>
        </Card>
      ) : (
        <div className="grid gap-2">
          {entries.map(e => (
            <WaitlistItem
              key={e.waitlist_id}
              item={e}
              role="student"
              onNotify={handleNotify}
              onCancel={handleCancel}
              loadingId={loadingId}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export function AdviserWaitlistView({ onRefresh }) {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [loadingId, setLoadingId] = useState(null);

  const load = useCallback(async () => {
    try {
      const data = await adviserWaitlist();
      setEntries(data);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleNotify = async (id) => {
    setLoadingId(id);
    setMsg({ type: "", text: "" });
    try {
      await notifyWaitlist(id);
      setMsg({ type: "ok", text: "Student notified. They have 48 hours to apply." });
      load();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  const handleCancel = async (id) => {
    setLoadingId(id);
    setMsg({ type: "", text: "" });
    try {
      await cancelWaitlist(id);
      setMsg({ type: "ok", text: "Waitlist entry cancelled." });
      load();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  return (
    <div className="grid gap-4">
      <div className="flex items-center justify-between">
        <CardTitle className="text-lg">Waitlist for Your Slots</CardTitle>
      </div>

      <Notice msg={msg} />

      {entries.length === 0 ? (
        <Card className="p-8 text-center border-dashed">
          <p className="text-muted-foreground">No students on your waitlist.</p>
        </Card>
      ) : (
        <div className="grid gap-2">
          {entries.map(e => (
            <WaitlistItem
              key={e.waitlist_id}
              item={e}
              role="adviser"
              onNotify={handleNotify}
              onCancel={handleCancel}
              loadingId={loadingId}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export default StudentWaitlist;