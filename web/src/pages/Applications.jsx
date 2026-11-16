import { useEffect, useState } from "react";
import { Link, useOutletContext } from "react-router-dom";
import { decideApplication, myApplications, withdrawApplication } from "@/api";
import { GroupMembers } from "@/components/GroupMembers";
import GroupInvitationInbox from "@/components/GroupInvitationInbox";
import StudentGroupRequestInbox from "@/components/StudentGroupRequestInbox";
import { Button } from "@/components/ui/button";
import { Notice } from "@/components/ui/alert";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { GlassCard, CardHeader, StatusPill, PersonChip, EmptyState, InfoRow } from "@/components/ui/bento";
import { AlertDialog, AlertDialogContent, AlertDialogHeader, AlertDialogTitle, AlertDialogDescription, AlertDialogFooter, AlertDialogAction, AlertDialogCancel } from "@/components/ui/alert-dialog";
import { FileText, CheckCircle2, XCircle } from "lucide-react";

export default function Applications() {
  const { status, refresh, user } = useOutletContext();
  const [items, setItems] = useState([]);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [activeTab, setActiveTab] = useState("pending");
  const [withdrawApp, setWithdrawApp] = useState(null);

  const load = () => myApplications().then((r) => setItems([...r].sort((a, b) => (a.status === "pending" ? 0 : 1) - (b.status === "pending" ? 0 : 1)))).catch((e) => setMsg({ type: "error", text: e.message }));
  useEffect(() => { load(); }, []);

  // Auto-switch to first tab with content
  useEffect(() => {
    const pendingItems = items.filter(a => a.status === "pending");
    const approvedItems = items.filter(a => a.status === "approved");
    const declinedItems = items.filter(a => a.status === "declined");
    if (pendingItems.length > 0) setActiveTab("pending");
    else if (approvedItems.length > 0) setActiveTab("approved");
    else if (declinedItems.length > 0) setActiveTab("declined");
  }, [items]);

  async function decide(a, decision) {
    try {
      await decideApplication(a.application_id, decision);
      setMsg({ type: "ok", text: decision === "approved" ? "Approved. The student can now book you." : "Declined." });
    } catch (e) { setMsg({ type: "error", text: e.message }); }
    load();
    refresh();
  }

  const pendingItems = items.filter(a => a.status === "pending");
  const approvedItems = items.filter(a => a.status === "approved");
  const declinedItems = items.filter(a => a.status === "declined");

  async function confirmWithdraw() {
    if (!withdrawApp) return;
    try {
      await withdrawApplication(withdrawApp.application_id);
      setMsg({ type: "ok", text: "Application withdrawn." });
      load();
      refresh();
    } catch (err) { setMsg({ type: "error", text: err.message }); }
    setWithdrawApp(null);
  }

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">{user.role === "student" ? "My Requests & Groups" : "Advisee requests"}</h1>
        <p className="text-foreground/70">{user.role === "student" ? "Track your adviser applications and respond to project group invitations." : "Students who applied to be advised by you."}</p>
      </div>
      <Notice msg={msg} />
      {user.role === "student" && (
        <>
          <GroupInvitationInbox onChange={load} />
          <StudentGroupRequestInbox />
        </>
      )}

      <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="pending"><span className="flex items-center gap-1">Pending <span className="bg-primary/20 text-primary px-2 py-0.5 rounded-full text-xs">{pendingItems.length}</span></span></TabsTrigger>
          <TabsTrigger value="approved"><span className="flex items-center gap-1">Approved <span className="bg-success/20 text-success px-2 py-0.5 rounded-full text-xs">{approvedItems.length}</span></span></TabsTrigger>
          <TabsTrigger value="declined"><span className="flex items-center gap-1">Declined <span className="bg-destructive/20 text-destructive px-2 py-0.5 rounded-full text-xs">{declinedItems.length}</span></span></TabsTrigger>
        </TabsList>

        <TabsContent value="pending">
          {pendingItems.length === 0 ? (
            <EmptyState
              icon={<FileText className="h-12 w-12" />}
              title={user.role === "student" ? "No pending applications" : "No pending requests"}
              description={user.role === "student" ? "Your adviser applications will appear here." : "Student applications will appear here when they apply to you."}
            />
          ) : (
            <div className="grid items-stretch gap-4 md:grid-cols-2 lg:grid-cols-3">
              {pendingItems.map((a) => (
                <GlassCard key={a.application_id} className="flex flex-col">
                  <CardHeader className="flex flex-row items-center justify-between gap-2">
                    <h3 className="text-lg font-semibold truncate">{a.student_name}</h3>
                    <StatusPill tone="warning" showDot>{a.status}</StatusPill>
                  </CardHeader>
                  <div className="grid content-start gap-2 p-4 pt-0">
                    <p className="text-sm">{a.topic_brief}</p>
                    <PersonChip avatar={a.student_profile_photo} name={a.student_name} subtitle={a.student_email} />
                    <small className="text-muted-foreground">Sent {a.date_submitted}</small>
                    <div className="flex gap-2 pt-2 border-t border-border/30">
                      <Button className="flex-1" onClick={() => decide(a, "approved")}>Approve</Button>
                      <Button variant="destructive" className="flex-1" onClick={() => decide(a, "declined")}>Decline</Button>
                    </div>
                  </div>
                </GlassCard>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="approved">
          {approvedItems.length === 0 ? (
            <EmptyState
              icon={<CheckCircle2 className="h-12 w-12" />}
              title={user.role === "student" ? "No approved projects yet" : "No approved advisees yet"}
              description={user.role === "student" ? "Approved adviser applications and groups you join will appear here." : "Approved applications will appear here."}
            />
          ) : (
            <div className="grid gap-4">
              {approvedItems.map((a) => (
                <GlassCard key={a.application_id}>
                  <CardHeader className="flex flex-row items-center justify-between gap-2">
                    <h3 className="text-lg font-semibold truncate">{a.student_name}</h3>
                    <StatusPill tone="success" showDot>{a.status}</StatusPill>
                  </CardHeader>
                  <div className="grid content-start gap-2 p-4 pt-0">
                    <p className="text-sm">{a.topic_brief}</p>
                    <PersonChip avatar={a.student_profile_photo} name={a.student_name} subtitle={a.student_email} />
                    <small className="text-muted-foreground">Sent {a.date_submitted}</small>
                    <div className="flex gap-2">
                      <Button asChild variant="secondary"><Link to={`/board?app=${a.application_id}`}>Open board</Link></Button>
                      <Button asChild variant="outline"><Link to={`/milestones?app=${a.application_id}`}>Milestones</Link></Button>
                    </div>
                    <div className="pt-2 border-t border-border/30">
                      <GroupMembers applicationId={a.application_id} user={user} />
                    </div>
                  </div>
                </GlassCard>
              ))}
            </div>
          )}
        </TabsContent>

        <TabsContent value="declined">
          {declinedItems.length === 0 ? (
            <EmptyState
              icon={<XCircle className="h-12 w-12" />}
              title={user.role === "student" ? "No declined applications" : "No declined requests"}
              description={user.role === "student" ? "Declined adviser applications will appear here." : "Declined applications will appear here."}
            />
          ) : (
            <div className="grid items-stretch gap-4 md:grid-cols-2 lg:grid-cols-3">
              {declinedItems.map((a) => (
                <GlassCard key={a.application_id}>
                  <CardHeader className="flex flex-row items-center justify-between gap-2">
                    <h3 className="text-lg font-semibold truncate">{a.student_name}</h3>
                    <StatusPill tone="destructive" showDot>{a.status}</StatusPill>
                  </CardHeader>
                  <div className="grid content-start gap-2 p-4 pt-0">
                    <p className="text-sm">{a.topic_brief}</p>
                    <PersonChip avatar={a.student_profile_photo} name={a.student_name} subtitle={a.student_email} />
                    <small className="text-muted-foreground">Sent {a.date_submitted}</small>
                  </div>
                </GlassCard>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* Withdraw Confirmation Dialog */}
      <AlertDialog open={Boolean(withdrawApp)} onOpenChange={(o) => { if (!o) setWithdrawApp(null); }}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Withdraw application?</AlertDialogTitle>
            <AlertDialogDescription>
              This will cancel your application to <strong>{withdrawApp?.adviser_name}</strong>. You can apply again later.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={confirmWithdraw} variant="destructive">Withdraw</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}