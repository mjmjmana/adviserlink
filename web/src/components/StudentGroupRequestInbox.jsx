import { useCallback, useEffect, useState } from "react";
import { useOutletContext } from "react-router-dom";
import { Check, Clock, X } from "lucide-react";
import { decideStudentGroupRequest, myStudentGroupRequests } from "@/api";
import { Button } from "@/components/ui/button";
import { Notice } from "@/components/ui/alert";
import { GlassCard } from "@/components/ui/bento";

export default function StudentGroupRequestInbox() {
  const { user } = useOutletContext();
  const [requests, setRequests] = useState([]);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [respondingId, setRespondingId] = useState(null);

  const load = useCallback(async () => {
    try {
      setRequests(await myStudentGroupRequests());
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function respond(request, decision) {
    setRespondingId(request.request_id);
    setMsg({ type: "", text: "" });
    try {
      await decideStudentGroupRequest(request.request_id, decision);
      setMsg({ type: "ok", text: `Group request ${decision}.` });
      await load();
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setRespondingId(null);
    }
  }

  if (requests.length === 0 && !msg.text) return null;
  return (
    <section className="grid gap-3">
      <h2 className="text-xl font-bold">Student group requests</h2>
      <Notice msg={msg} />
      {requests.map((request) => {
        const incoming = Boolean(request.can_decide);
        const approved = request.status === "approved";
        const memberRequest = request.requested_by === "member";
        const partnerName = request.other_name || (
          request.leader_id === user.user_id ? request.member_name : request.leader_name
        );
        const partnerEmail = request.other_email || (
          request.leader_id === user.user_id ? request.member_email : request.leader_email
        );
        const label = approved
          ? memberRequest ? `${partnerName} joined your group` : `You joined ${partnerName}'s group`
          : incoming
            ? memberRequest ? `${partnerName} wants to join your group` : `${partnerName} invited you to join a group`
            : memberRequest ? `Join request sent to ${partnerName}` : `Invitation sent to ${partnerName}`;
        return (
          <GlassCard key={request.request_id} className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <p className="font-semibold">{label}</p>
              <p className="text-sm text-muted-foreground">
                {partnerEmail}
              </p>
            </div>
            {approved ? (
              <span className="text-sm font-semibold text-success">Accepted</span>
            ) : incoming ? (
              <div className="flex gap-2">
                <Button size="sm" onClick={() => respond(request, "approved")} disabled={respondingId === request.request_id}>
                  <Check className="h-4 w-4" /> Accept
                </Button>
                <Button size="sm" variant="outline" onClick={() => respond(request, "declined")} disabled={respondingId === request.request_id}>
                  <X className="h-4 w-4" /> Decline
                </Button>
              </div>
            ) : (
              <span className="flex items-center gap-1 text-sm text-muted-foreground"><Clock className="h-4 w-4" /> Pending</span>
            )}
          </GlassCard>
        );
      })}
    </section>
  );
}
