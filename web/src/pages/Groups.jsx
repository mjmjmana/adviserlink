import { useCallback, useEffect, useState } from "react";
import { useOutletContext } from "react-router-dom";
import { Building2, Check, Clock, Search, Users, UserRound, Send, Eye, X } from "lucide-react";
import { createStudentGroupRequest, decideStudentGroupRequest, getAvailableGroupMembers, getAvailableGroups, myStudentGroupRequests } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Notice } from "@/components/ui/alert";
import { GlassCard, CardHeader, EmptyState } from "@/components/ui/bento";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";

export default function Groups() {
  const { user, status } = useOutletContext();
  const isLeader = user?.student_group_role !== "member";
  const [groups, setGroups] = useState([]);
  const [members, setMembers] = useState([]);
  const [query, setQuery] = useState("");
  const [loadingId, setLoadingId] = useState(null);
  const [searching, setSearching] = useState(false);
  const [hasSearched, setHasSearched] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [requests, setRequests] = useState([]);
  const [respondingId, setRespondingId] = useState(null);

  const loadRequests = useCallback(async () => {
    try {
      setRequests(await myStudentGroupRequests());
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    }
  }, []);

  useEffect(() => {
    loadRequests();
  }, [loadRequests]);

  const loadGroups = useCallback(async (searchTerm) => {
    try {
      setGroups(await getAvailableGroups(searchTerm));
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    }
  }, []);

  async function searchMembers(event) {
    event.preventDefault();
    const topic = query.trim();
    if (!topic) {
      setMsg({ type: "error", text: "Enter a keyword, member name, or email to search." });
      setMembers([]);
      setHasSearched(false);
      return;
    }
    setSearching(true);
    setHasSearched(true);
    setMsg({ type: "", text: "" });
    try {
      setMembers(await getAvailableGroupMembers(topic));
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setSearching(false);
    }
  }

  async function inviteMember(member) {
    setLoadingId(member.user_id);
    setMsg({ type: "", text: "" });
    try {
      await createStudentGroupRequest(member.user_id);
      setMsg({ type: "ok", text: `Group request sent to ${member.name}. They can accept or decline it in Requests.` });
      setMembers((current) => current.filter((candidate) => candidate.user_id !== member.user_id));
      await loadRequests();
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setLoadingId(null);
    }
  }

  async function submitRequest(group) {
    setLoadingId(group.leader_id);
    setMsg({ type: "", text: "" });
    try {
      await createStudentGroupRequest(group.leader_id);
      setMsg({ type: "ok", text: "Join request sent to the group leader." });
      setSelectedGroup(null);
      await loadGroups(query.trim());
      await loadRequests();
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setLoadingId(null);
    }
  }

  async function searchGroups(event) {
    event.preventDefault();
    const searchTerm = query.trim();
    if (!searchTerm) {
      setMsg({ type: "error", text: "Enter a topic keyword, leader name, or email to search." });
      setGroups([]);
      setHasSearched(false);
      return;
    }
    setSearching(true);
    setHasSearched(true);
    setMsg({ type: "", text: "" });
    try {
      await loadGroups(searchTerm);
    } finally {
      setSearching(false);
    }
  }

  async function respondToRequest(request, decision) {
    setRespondingId(request.request_id);
    setMsg({ type: "", text: "" });
    try {
      await decideStudentGroupRequest(request.request_id, decision);
      await loadRequests();
      if (!isLeader && hasSearched) await loadGroups(query.trim());
      setMsg({ type: "ok", text: `Group request ${decision}.` });
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setRespondingId(null);
    }
  }

  function renderRequests() {
    if (requests.length === 0) return null;
    return (
      <section className="grid gap-3">
        <h2 className="text-xl font-bold">Group requests</h2>
        {requests.map((request) => {
          const incoming = Boolean(request.can_decide) && request.status === "pending";
          const approved = request.status === "approved";
          const isMemberRequest = request.requested_by === "member";
          const partnerName = request.other_name || (
            request.leader_id === user.user_id ? request.member_name : request.leader_name
          );
          const partnerEmail = request.other_email || (
            request.leader_id === user.user_id ? request.member_email : request.leader_email
          );
          const label = approved
            ? isMemberRequest ? `${partnerName} joined your group` : `You joined ${partnerName}'s group`
            : incoming
              ? isMemberRequest ? `${partnerName} wants to join your group` : `${partnerName} invited you to join a group`
              : isMemberRequest ? `Join request sent to ${partnerName}` : `Invitation sent to ${partnerName}`;
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
                  <Button size="sm" onClick={() => respondToRequest(request, "approved")} disabled={respondingId === request.request_id}>
                    <Check className="h-4 w-4" /> Accept
                  </Button>
                  <Button size="sm" variant="outline" onClick={() => respondToRequest(request, "declined")} disabled={respondingId === request.request_id}>
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

  if (isLeader) {
    return (
      <>
        <div className="grid gap-1">
          <h1 className="text-3xl font-extrabold tracking-tight">Find Members</h1>
          <p className="text-foreground/70">Search for students who share similar research interests and are not yet in a group or advised.</p>
        </div>
        {!status?.application?.status || status.application.status !== "approved" ? (
          <div className="rounded-xl border border-primary/20 bg-primary/5 p-4 text-sm">
            You can connect with members now. Only group leaders can apply to an adviser; you do not need an approved adviser to send or respond to group requests.
          </div>
        ) : null}
        {renderRequests()}
        <Notice msg={msg} />
        <form className="flex gap-2" onSubmit={searchMembers}>
          <Input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Search a title keyword, member name, or email"
            aria-label="Search by project title keyword, member name, or email"
          />
          <Button type="submit" disabled={searching}><Search className="h-4 w-4" />{searching ? "Searching…" : "Search"}</Button>
        </form>
        <p className="text-xs text-muted-foreground">
          Search using a few keywords. Matches can come from your project title, a member&apos;s name or email, or their research interests.
        </p>

        {members.length === 0 ? (
          <EmptyState
            icon={<UserRound className="h-12 w-12" />}
            title={searching ? "Searching available members" : hasSearched ? "No matching members found" : "Search for a member"}
            description={hasSearched
              ? "Try a shorter keyword, part of a name or email, or a topic from your project title."
              : "Enter a few keywords, a member name, or an email. You do not need to type the full project topic."}
          />
        ) : (
          <div className="grid items-stretch gap-4 md:grid-cols-2">
            {members.map((member) => (
              <GlassCard key={member.user_id} className="flex flex-col gap-4">
                <div className="flex items-center gap-3">
                  {member.profile_photo ? (
                    <img src={member.profile_photo} alt="" className="h-12 w-12 rounded-full object-cover" />
                  ) : (
                    <span className="grid h-12 w-12 place-items-center rounded-full bg-primary/15 font-bold text-primary">
                      {(member.name || "?").trim().charAt(0).toUpperCase() || "?"}
                    </span>
                  )}
                  <div className="min-w-0">
                    <p className="font-semibold">{member.name}</p>
                    <p className="text-sm text-muted-foreground">{member.email}</p>
                  </div>
                  <span className="ml-auto rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary">
                    {member.matched_by === "name or email"
                      ? "Name/email match"
                      : member.matched_by === "project title"
                        ? "Title match"
                        : "Interest match"}
                  </span>
                </div>
                <div className="flex-1 rounded-xl bg-muted/40 p-3">
                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Thesis / capstone title</p>
                  <p className="text-sm">{member.thesis_title}</p>
                  {member.research_interests && (
                    <p className="mt-3 text-sm text-muted-foreground">
                      <span className="font-semibold">Research interests: </span>{member.research_interests}
                    </p>
                  )}
                  {member.matched_topics.length > 0 && (
                    <p className="mt-2 text-xs text-muted-foreground">Matched keywords: {member.matched_topics.join(", ")}</p>
                  )}
                  {member.matched_title_topics.length > 0 && (
                    <p className="mt-1 text-xs text-muted-foreground">Related to your project: {member.matched_title_topics.join(", ")}</p>
                  )}
                </div>
                <Button onClick={() => inviteMember(member)} disabled={loadingId === member.user_id}>
                  <Send className="h-4 w-4" />
                  {loadingId === member.user_id ? "Sending…" : "Request this member"}
                </Button>
              </GlassCard>
            ))}
          </div>
        )}
      </>
    );
  }

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Find a Project Group</h1>
        <p className="text-foreground/70">Search for a project and review its details before requesting to join.</p>
      </div>
      {renderRequests()}
      <Notice msg={msg} />
      <form className="flex gap-2" onSubmit={searchGroups}>
        <Input
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search a topic keyword, group leader name, or email"
          aria-label="Search project groups by topic keyword, leader name, or email"
        />
        <Button type="submit" disabled={searching}><Search className="h-4 w-4" />{searching ? "Searching…" : "Search"}</Button>
      </form>
      <p className="text-xs text-muted-foreground">
        Results include groups similar to your saved thesis title, plus matches for the keywords or leader name/email you search.
      </p>

      {groups.length === 0 ? (
        <EmptyState
          icon={<Users className="h-12 w-12" />}
          title={searching ? "Searching project groups" : hasSearched ? "No matching groups found" : "Search for a project group"}
          description={hasSearched
            ? "Try a shorter keyword, part of a leader's name or email, or a related topic."
            : "Enter a project keyword, group leader name, or email. Results will only appear after you search."}
        />
      ) : (
        <div className="grid items-stretch gap-4 md:grid-cols-2">
          {groups.map((group) => {
            const occupiedSpots = group.member_count + group.reserved_count;
            const memberInitial = (group.leader_name || "?").trim().charAt(0).toUpperCase() || "?";
            return (
              <GlassCard key={group.leader_id} className="flex flex-col gap-4">
                <CardHeader
                  icon={<Building2 className="h-5 w-5" />}
                  title={group.adviser_name || "Group leader"}
                  description={group.adviser_name ? "Approved adviser" : "Not connected to an adviser yet"}
                />
                <div className="flex items-center gap-3">
                  {group.leader_profile_photo ? (
                    <img src={group.leader_profile_photo} alt="" className="h-11 w-11 rounded-full object-cover" />
                  ) : (
                    <span className="grid h-11 w-11 place-items-center rounded-full bg-primary/15 font-bold text-primary">{memberInitial}</span>
                  )}
                  <div className="min-w-0">
                    <p className="font-semibold">{group.leader_name}</p>
                    <p className="truncate text-sm text-muted-foreground">{group.leader_email}</p>
                  </div>
                  <span className="ml-auto flex items-center gap-1 text-sm text-muted-foreground">
                    <Users className="h-4 w-4" /> {occupiedSpots}/4
                  </span>
                </div>
                <div className="flex-1 rounded-xl bg-muted/40 p-3">
                  <p className="mb-1 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Project topic</p>
                  <p className="whitespace-pre-wrap text-sm">{group.topic_brief}</p>
                  {group.matched_topics.length > 0 && (
                    <p className="mt-2 text-xs text-muted-foreground">
                      Matched keywords: {group.matched_topics.join(", ")} · Match from {group.matched_by}
                    </p>
                  )}
                </div>
                {(group.member_count > 0 || group.reserved_count > 0) && (
                  <p className="text-xs text-muted-foreground">
                    {group.member_count} member{group.member_count === 1 ? "" : "s"}
                    {group.reserved_count > 0 ? ` · ${group.reserved_count} pending request${group.reserved_count === 1 ? "" : "s"}` : ""}
                  </p>
                )}
                <div className="flex justify-end">
                  {group.request_status === "pending" && !group.has_pending_invitation ? (
                    <Button disabled variant="outline"><Clock className="h-4 w-4" /> Request pending</Button>
                  ) : group.has_pending_invitation ? (
                    <Button disabled variant="outline"><Clock className="h-4 w-4" /> Invitation received</Button>
                  ) : group.has_pending_request ? (
                    <Button disabled variant="outline">Another join request is pending</Button>
                  ) : group.has_any_pending_invitation ? (
                    <Button disabled variant="outline">Respond to your invitation above</Button>
                  ) : (
                    <Button variant="outline" onClick={() => setSelectedGroup(group)}>
                      <Eye className="h-4 w-4" /> View group
                    </Button>
                  )}
                </div>
              </GlassCard>
            );
          })}
        </div>
      )}
      <Dialog open={Boolean(selectedGroup)} onOpenChange={(open) => !open && setSelectedGroup(null)}>
        <DialogContent>
          {selectedGroup && (
            <>
              <DialogHeader>
                <DialogTitle>Project group details</DialogTitle>
                <DialogDescription>Review the group before sending a join request.</DialogDescription>
              </DialogHeader>
              <div className="grid gap-4">
                <div>
                  <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Complete project title</p>
                  <p className="mt-1 whitespace-pre-wrap font-semibold">{selectedGroup.topic_brief}</p>
                </div>
                <div className="grid gap-1 text-sm">
                  <p><span className="font-semibold">Group leader:</span> {selectedGroup.leader_name}</p>
                  <p><span className="font-semibold">Email:</span> {selectedGroup.leader_email}</p>
                  <p><span className="font-semibold">Adviser:</span> {selectedGroup.adviser_name}</p>
                  <p><span className="font-semibold">Members:</span> {selectedGroup.member_count} / 4</p>
                </div>
                <Button
                  onClick={() => submitRequest(selectedGroup)}
                  disabled={loadingId === selectedGroup.leader_id || selectedGroup.member_count + selectedGroup.reserved_count >= 4}
                >
                  <Send className="h-4 w-4" />
                  {loadingId === selectedGroup.leader_id
                    ? "Sending request…"
                    : selectedGroup.member_count + selectedGroup.reserved_count >= 4
                      ? "Group is full"
                      : selectedGroup.request_status === "declined" ? "Request again" : "Request to join"}
                </Button>
              </div>
            </>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
