import { useEffect, useState } from "react";
import { useOutletContext } from "react-router-dom";
import { Check, UserCheck, Users } from "lucide-react";
import { adminUsers, setUserStatus } from "@/api";
import { Button } from "@/components/ui/button";
import { Notice } from "@/components/ui/alert";
import { EmptyState, GlassCard, PersonChip } from "@/components/ui/bento";

export default function AdviserApprovals() {
  const { refresh } = useOutletContext();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [msg, setMsg] = useState(null);

  function load() {
    setLoading(true);
    return adminUsers("", "adviser", "pending", 200)
      .then((result) => setRows(result.items))
      .catch((error) => setMsg({ type: "error", text: error.message }))
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(); }, []);

  async function approve(adviser) {
    setBusyId(adviser.user_id);
    setMsg(null);
    try {
      await setUserStatus(adviser.user_id, "active");
      setMsg({ type: "ok", text: `${adviser.name}'s adviser account has been approved.` });
      await load();
      await refresh();
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setBusyId(null);
    }
  }

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Adviser approvals</h1>
        <p className="text-foreground/70">Review adviser account requests. Advisers can log in after an admin approves them.</p>
      </div>
      <Notice msg={msg} />
      {loading ? (
        <p className="text-sm text-muted-foreground" role="status">Loading adviser requests…</p>
      ) : rows.length === 0 ? (
        <GlassCard>
          <EmptyState
            icon={<UserCheck className="h-12 w-12" />}
            title="No adviser requests"
            description="New adviser account requests will appear here for review."
          />
        </GlassCard>
      ) : (
        <div className="grid gap-3">
          <p className="text-sm text-muted-foreground">{rows.length} adviser request(s) waiting for approval</p>
          {rows.map((adviser) => (
            <GlassCard key={adviser.user_id} className="flex flex-wrap items-center justify-between gap-4">
              <div className="flex min-w-0 flex-1 items-center gap-3">
                <PersonChip avatar={adviser.profile_photo} name={adviser.name} subtitle={adviser.email} />
                <div className="hidden items-center gap-1.5 text-xs text-muted-foreground sm:flex">
                  <Users className="h-3.5 w-3.5" />
                  Adviser
                  {adviser.created_at && <span>· Requested {new Date(adviser.created_at).toLocaleDateString()}</span>}
                </div>
              </div>
              <Button onClick={() => approve(adviser)} disabled={busyId !== null}>
                <Check className="mr-1.5 h-4 w-4" />
                {busyId === adviser.user_id ? "Approving…" : "Approve adviser"}
              </Button>
            </GlassCard>
          ))}
        </div>
      )}
    </>
  );
}
