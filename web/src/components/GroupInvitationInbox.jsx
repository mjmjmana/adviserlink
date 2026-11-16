import { useCallback, useEffect, useState } from "react";
import { Check, Loader2, X } from "lucide-react";
import { acceptGroupInvitation, declineGroupInvitation, myGroupInvitations } from "@/api";
import { Button } from "@/components/ui/button";
import { GlassCard, CardHeader } from "@/components/ui/bento";
import { Notice } from "@/components/ui/alert";

export default function GroupInvitationInbox({ onChange }) {
  const [invitations, setInvitations] = useState([]);
  const [loadingId, setLoadingId] = useState(null);
  const [msg, setMsg] = useState({ type: "", text: "" });

  const load = useCallback(async () => {
    try {
      setInvitations(await myGroupInvitations());
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function respond(invitation, accept) {
    setLoadingId(invitation.invitation_id);
    setMsg({ type: "", text: "" });
    try {
      if (accept) await acceptGroupInvitation(invitation.invitation_id);
      else await declineGroupInvitation(invitation.invitation_id);
      setMsg({ type: "ok", text: accept ? "You joined the project group." : "Invitation declined." });
      await load();
      onChange?.();
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setLoadingId(null);
    }
  }

  if (!invitations.length && !msg.text) return null;

  return (
    <GlassCard className="grid gap-3 p-4">
      <CardHeader title="Project group invitations" description="Accept to join the group, or decline if you don't want to join." />
      <Notice msg={msg} />
      {invitations.map((invitation) => (
        <div key={invitation.invitation_id} className="flex flex-wrap items-center justify-between gap-3 rounded-xl bg-muted/50 p-3">
          <div className="min-w-0">
            <p className="font-semibold">{invitation.invited_by_name} invited you to join a project group</p>
            <p className="text-sm text-muted-foreground">Adviser: {invitation.adviser_name}</p>
            <p className="text-sm">{invitation.topic_brief}</p>
          </div>
          <div className="flex gap-2">
            <Button onClick={() => respond(invitation, true)} disabled={loadingId === invitation.invitation_id}>
              {loadingId === invitation.invitation_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="mr-1 h-4 w-4" />}
              Accept
            </Button>
            <Button variant="outline" onClick={() => respond(invitation, false)} disabled={loadingId === invitation.invitation_id}>
              <X className="mr-1 h-4 w-4" /> Decline
            </Button>
          </div>
        </div>
      ))}
    </GlassCard>
  );
}
