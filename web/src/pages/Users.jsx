import { useEffect, useState } from "react";
import { useNavigate, useOutletContext, useSearchParams } from "react-router-dom";
import { ArrowLeft, Search, User, Users as UsersIcon, UserPlus, UserCheck, UserX } from "lucide-react";
import { adminUsers, setUserStatus } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Notice } from "@/components/ui/alert";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { GlassCard, StatusPill, PersonChip, EmptyState } from "@/components/ui/bento";

const ROLE_TONES = { student: "default", adviser: "primary", admin: "dark" };
const STATUS_TONES = { active: "success", pending: "warning", disabled: "destructive" };
const PAGE_SIZE = 50;

export default function Users() {
  const { user, refresh } = useOutletContext();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const fromAnalytics = searchParams.get("from") === "analytics";
  const requestedRole = searchParams.get("role");
  const [q, setQ] = useState("");
  const [role, setRole] = useState(["student", "adviser", "admin"].includes(requestedRole) ? requestedRole : "");
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [msg, setMsg] = useState({ type: "", text: "" });
  const load = (query = q, r = role, currentPage = page) => adminUsers(query, r, "", PAGE_SIZE, currentPage * PAGE_SIZE)
    .then((result) => {
      const lastPage = Math.max(0, Math.ceil(result.total / PAGE_SIZE) - 1);
      setTotal(result.total);
      if (currentPage > lastPage) {
        setPage(lastPage);
        return;
      }
      setRows(result.items);
      setMsg({ type: "", text: "" });
    })
    .catch((e) => setMsg({ type: "error", text: e.message }));
  useEffect(() => { load(q, role, page); }, [role, page]);

  function changeRole(nextRole) {
    setRole(nextRole);
    setPage(0);
  }

  async function change(u, status, okText) {
    try { await setUserStatus(u.user_id, status); setMsg({ type: "ok", text: `${u.name}: ${okText}` }); } catch (e) { setMsg({ type: "error", text: e.message }); }
    load();
    refresh();
  }

  return (
    <>
      {fromAnalytics && (
        <Button variant="ghost" className="w-fit px-0" onClick={() => navigate("/analytics")}>
          <ArrowLeft /> Back to Analytics
        </Button>
      )}
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Users</h1>
        <p className="text-foreground/70">Everyone who has an AdviserLink account. New advisers must be approved before they can log in.</p>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Tabs value={role} onValueChange={changeRole}>
          <TabsList className="bg-muted text-foreground">
            <TabsTrigger value=""><span>All</span></TabsTrigger>
            <TabsTrigger value="student"><span>Students</span></TabsTrigger>
            <TabsTrigger value="adviser"><span>Advisers</span></TabsTrigger>
            <TabsTrigger value="admin"><span>Admins</span></TabsTrigger>
          </TabsList>
        </Tabs>
        <form className="flex flex-1 gap-2 sm:max-w-md" onSubmit={(e) => { e.preventDefault(); page === 0 ? load(q, role, 0) : setPage(0); }}>
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name or email" />
          <Button type="submit"><Search /> Search</Button>
        </form>
        <span className="text-sm text-foreground/70">
          Showing {total === 0 ? 0 : page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, total)} of {total} account(s)
        </span>
      </div>
      <Notice msg={msg} />
      <GlassCard className="overflow-hidden">
        <div className="overflow-x-auto p-2">
          <table className="w-full min-w-[48rem] text-left text-sm">
            <thead>
              <tr className="text-xs uppercase tracking-wide text-muted-foreground">
                <th className="p-3">Name</th>
                <th className="p-3">Email</th>
                <th className="p-3">Role</th>
                <th className="p-3">Status</th>
                <th className="p-3">Adviser / Advisees</th>
                <th className="p-3">Joined</th>
                <th className="p-3">Action</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={u.user_id} className="border-t border-border/50">
                  <td className="p-3">
                    <PersonChip avatar={u.profile_photo} name={u.name} subtitle={u.email} />
                  </td>
                  <td className="p-3">{u.email}</td>
                  <td className="p-3">
                    <StatusPill tone={ROLE_TONES[u.role]} showDot>{u.role}</StatusPill>
                  </td>
                  <td className="p-3">
                    <StatusPill tone={STATUS_TONES[u.account_status] || "default"} showDot>{u.account_status}</StatusPill>
                  </td>
                  <td className="p-3 text-sm text-muted-foreground">
                    {u.role === "adviser" ? `${u.advisees} advisee(s)` : u.role === "student" ? (
                      u.adviser_name ? (
                        <span className="inline-flex items-center gap-2">
                          {u.adviser_profile_photo ? (
                            <img src={u.adviser_profile_photo} alt="" className="h-7 w-7 rounded-full object-cover" />
                          ) : (
                            <span className="flex h-7 w-7 items-center justify-center rounded-full bg-primary/20 text-xs font-bold text-primary">{u.adviser_name.charAt(0).toUpperCase()}</span>
                          )}
                          {u.adviser_name}
                        </span>
                      ) : "No adviser yet"
                    ) : "–"}
                  </td>
                  <td className="p-3 text-muted-foreground">{(u.created_at || "").slice(0, 10)}</td>
                  <td className="p-3">
                    {u.role !== "admin" && u.user_id !== user.user_id && (
                      u.account_status === "pending" ? (
                        <Button size="sm" onClick={() => change(u, "active", "approved.")}>
                          <UserCheck className="h-3.5 w-3.5 mr-1.5" /> Approve
                        </Button>
                      ) : u.account_status === "disabled" ? (
                        <Button size="sm" variant="secondary" onClick={() => change(u, "active", "reactivated.")}>
                          <UserPlus className="h-3.5 w-3.5 mr-1.5" /> Reactivate
                        </Button>
                      ) : (
                        <Button size="sm" variant="ghost" className="text-destructive" onClick={() => change(u, "disabled", "deactivated.")}>
                          <UserX className="h-3.5 w-3.5 mr-1.5" /> Deactivate
                        </Button>
                      )
                    )}
                  </td>
                </tr>
              ))}
              {rows.length === 0 && (
                <tr>
                  <td className="p-6 text-center text-muted-foreground" colSpan={7}>
                    <EmptyState icon={<UsersIcon className="h-12 w-12" />} title="No accounts found" description="Try a different search or filter." />
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>
      {total > PAGE_SIZE && (
        <div className="flex items-center justify-between gap-3">
          <span className="text-sm text-muted-foreground">Page {page + 1} of {Math.ceil(total / PAGE_SIZE)}</span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage((current) => current - 1)}>Previous</Button>
            <Button variant="outline" size="sm" disabled={(page + 1) * PAGE_SIZE >= total} onClick={() => setPage((current) => current + 1)}>Next</Button>
          </div>
        </div>
      )}
    </>
  );
}