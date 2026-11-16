import { useCallback, useEffect, useState } from "react";
import { Check, Loader2, Plus, UserCheck, UserX, X } from "lucide-react";
import { cancelGroupInvitation, decideGroupJoinRequest, getGroupInvitations, getGroupJoinRequests, getGroupMembers, inviteGroupMember, removeGroupMember } from "@/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

export function GroupMembers({ applicationId, user, onChange }) {
  const [members, setMembers] = useState([]);
  const [invitations, setInvitations] = useState([]);
  const [joinRequests, setJoinRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ student_email: "" });
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [error, setError] = useState("");
  const [loadingId, setLoadingId] = useState(null);

  const load = useCallback(async () => {
    if (!applicationId) return;
    try {
      const data = await getGroupMembers(applicationId);
      setMembers(data);
      if (user.role === "student" && data.some((member) => member.student_id === user.user_id && member.is_leader)) {
        const [pendingInvitations, pendingRequests] = await Promise.all([
          getGroupInvitations(applicationId),
          getGroupJoinRequests(applicationId),
        ]);
        setInvitations(pendingInvitations);
        setJoinRequests(pendingRequests);
      } else {
        setInvitations([]);
        setJoinRequests([]);
      }
    } catch (e) {
      setError(e.message);
    }
  }, [applicationId, user.role, user.user_id]);

  useEffect(() => {
    load();
  }, [load]);

  const isGroupLeader = user.role === "student" && members.some((member) => member.student_id === user.user_id && member.is_leader);
  const canManage = isGroupLeader;
  const capacityReached = members.length + invitations.length + joinRequests.length >= 4;

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.student_email.trim()) return;
    setLoading(true);
    setMsg({ type: "", text: "" });
    try {
      await inviteGroupMember(applicationId, form);
      setMsg({ type: "ok", text: "Invitation sent. The student must accept before joining." });
      setShowForm(false);
      setForm({ student_email: "" });
      load();
      onChange?.();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  };

  const handleCancelInvitation = async (invitation) => {
    setLoadingId(invitation.invitation_id);
    setMsg({ type: "", text: "" });
    try {
      await cancelGroupInvitation(invitation.invitation_id);
      setMsg({ type: "ok", text: "Invitation cancelled." });
      await load();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  const handleJoinRequest = async (request, status) => {
    setLoadingId(request.request_id);
    setMsg({ type: "", text: "" });
    try {
      await decideGroupJoinRequest(request.request_id, status);
      setMsg({ type: "ok", text: status === "approved" ? `${request.student_name} joined the group.` : "Join request declined." });
      await load();
      onChange?.();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  const handleRemove = async (member) => {
    // Don't allow removing yourself if you're the only leader
    if (member.student_id === user.user_id && member.is_leader) {
      const otherLeaders = members.filter(m => m.is_leader && m.student_id !== user.user_id);
      if (otherLeaders.length === 0) {
        setMsg({ type: "error", text: "You cannot remove yourself as the only leader. Assign another leader first." });
        return;
      }
    }
    setLoadingId(member.group_id);
    setMsg({ type: "", text: "" });
    try {
      await removeGroupMember(member.group_id);
      setMsg({ type: "ok", text: "Group member removed." });
      load();
      onChange?.();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingId(null);
    }
  };

  const isCurrentUser = (member) => member.student_id === user.user_id;

  return (
    <div className="grid gap-4">
      <div className="flex items-center justify-between">
        <CardTitle className="text-lg">Group Members</CardTitle>
        {canManage && !capacityReached && (
          <Button onClick={() => setShowForm(true)}><Plus className="h-4 w-4 mr-2" /> Invite Member</Button>
        )}
      </div>

      <Notice msg={msg} />
      {error && <Notice msg={{ type: "error", text: error }} />}

      {showForm && canManage && !capacityReached && (
        <Card className="p-4 border-primary/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-base">Invite a Student</CardTitle>
          </CardHeader>
          <CardContent className="grid gap-3">
            <form onSubmit={handleSubmit} className="grid gap-3">
              <div className="grid gap-1.5">
                <Label htmlFor="gm-email">Student Email *</Label>
                <Input id="gm-email" type="email" value={form.student_email} onChange={(e) => setForm({ ...form, student_email: e.target.value })} required placeholder="student@university.edu" maxLength={255} />
              </div>
              <div className="flex gap-2">
                <Button type="submit" disabled={loading}>
                  {loading ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : "Send Invitation"}
                </Button>
                <Button type="button" variant="outline" onClick={() => { setShowForm(false); setForm({ student_email: "" }); }}>
                  <X className="h-4 w-4 mr-1" /> Cancel
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      {members.length === 0 ? (
        <Card className="p-8 text-center border-dashed">
          <p className="text-muted-foreground">No group members yet.</p>
          {canManage && <p className="text-sm text-muted-foreground mt-1">Invite students to collaborate on this application.</p>}
        </Card>
      ) : (
        <div className="grid gap-2">
          {members.map((m) => (
            <Card key={m.group_id} className="p-3 flex items-center justify-between">
              <div className="flex items-center gap-3 min-w-0 flex-1">
                {m.profile_photo ? (
                  <img src={m.profile_photo} alt="" className="h-10 w-10 shrink-0 rounded-full object-cover" />
                ) : (
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 font-bold text-primary">
                    {m.name?.[0]?.toUpperCase() || "?"}
                  </div>
                )}
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="font-medium truncate">{m.name}</p>
                    {m.is_leader && <Badge variant="primary"><UserCheck className="h-3 w-3 mr-1" /> Leader</Badge>}
                    {isCurrentUser(m) && <Badge variant="secondary">You</Badge>}
                  </div>
                  <p className="text-sm text-muted-foreground truncate">{m.email}</p>
                </div>
              </div>
              <div className="flex gap-1 shrink-0">
                {canManage && !isCurrentUser(m) && (
                  <Button variant="ghost" size="icon" className="text-destructive" onClick={() => handleRemove(m)} disabled={loadingId === m.group_id} aria-label="Remove member">
                    {loadingId === m.group_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <UserX className="h-4 w-4" />}
                  </Button>
                )}
                {canManage && isCurrentUser(m) && !m.is_leader && (
                  <Button variant="ghost" size="icon" onClick={() => handleRemove(m)} disabled={loadingId === m.group_id} aria-label="Leave group">
                    {loadingId === m.group_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <UserX className="h-4 w-4" />}
                  </Button>
                )}
              </div>
            </Card>
          ))}
        </div>
      )}
      {invitations.length > 0 && (
        <div className="grid gap-2">
          <h4 className="font-semibold">Pending invitations</h4>
          {invitations.map((invitation) => (
            <Card key={invitation.invitation_id} className="p-3 flex items-center justify-between gap-3">
              <div className="min-w-0">
                <p className="font-medium truncate">{invitation.student_name}</p>
                <p className="text-sm text-muted-foreground truncate">{invitation.email}</p>
              </div>
              <Button variant="outline" size="sm" onClick={() => handleCancelInvitation(invitation)} disabled={loadingId === invitation.invitation_id}>
                {loadingId === invitation.invitation_id ? <Loader2 className="h-4 w-4 animate-spin" /> : "Cancel"}
              </Button>
            </Card>
          ))}
        </div>
      )}
      {joinRequests.length > 0 && (
        <div className="grid gap-2">
          <h4 className="font-semibold">Join requests</h4>
          {joinRequests.map((request) => (
            <Card key={request.request_id} className="flex flex-wrap items-center justify-between gap-3 p-3">
              <div className="flex min-w-0 items-center gap-3">
                {request.student_profile_photo ? (
                  <img src={request.student_profile_photo} alt="" className="h-10 w-10 rounded-full object-cover" />
                ) : (
                  <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-primary/10 font-bold text-primary">
                    {request.student_name?.[0]?.toUpperCase() || "?"}
                  </span>
                )}
                <div className="min-w-0">
                  <p className="truncate font-medium">{request.student_name}</p>
                  <p className="truncate text-sm text-muted-foreground">{request.student_email}</p>
                </div>
              </div>
              <div className="flex gap-2">
                <Button size="sm" onClick={() => handleJoinRequest(request, "approved")} disabled={loadingId === request.request_id}>
                  {loadingId === request.request_id ? <Loader2 className="h-4 w-4 animate-spin" /> : <Check className="mr-1 h-4 w-4" />}
                  Approve
                </Button>
                <Button size="sm" variant="outline" onClick={() => handleJoinRequest(request, "declined")} disabled={loadingId === request.request_id}>
                  <X className="mr-1 h-4 w-4" /> Decline
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}

      <p className="text-sm text-muted-foreground">
        Maximum 4 members per group. {isGroupLeader ? "As the student group leader, you can invite students or approve/decline join requests." : "Only the student group leader can invite members or decide join requests."}
      </p>
    </div>
  );
}

export default GroupMembers;