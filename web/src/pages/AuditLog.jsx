import { useCallback, useEffect, useState } from "react";
import { Download, Loader2, RefreshCw, Search, FileSpreadsheet, FileText, Filter } from "lucide-react";
import { getAdminAuditLog, exportUsersCSV, exportApplicationsCSV, exportBookingsCSV, exportAnalyticsReport } from "@/api";
import { useOutletContext } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Notice } from "@/components/ui/alert";
import { cn } from "@/lib/utils";
import { format } from "date-fns";
import { GlassCard, CardHeader, StatusPill, EmptyState } from "@/components/ui/bento";

const ACTION_TONES = {
  create: "primary",
  update: "warning",
  delete: "destructive",
  approve: "success",
  reject: "destructive",
  export: "default",
  status_change: "warning",
  notify: "primary",
  cancel: "destructive",
};

function getActionTone(action) {
  const key = action.toLowerCase().replace(/\s+/g, "_");
  return ACTION_TONES[key] || "default";
}

function ExportButton({ label, icon: Icon, type, fn, exportLoading, onExport }) {
  return (
    <Button
      variant="outline"
      className="w-full justify-start gap-2"
      onClick={() => onExport(type, fn)}
      disabled={exportLoading === type}
    >
      <Icon className="h-4 w-4" />
      {exportLoading === type ? <Loader2 className="h-4 w-4 animate-spin" /> : label}
    </Button>
  );
}

export default function AuditLog() {
  const { triggerRefreshAnimation } = useOutletContext();
  const [logs, setLogs] = useState([]);
  const [loading, setLoading] = useState(false);
  const [limit, setLimit] = useState(100);
  const [filter, setFilter] = useState("");
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [exportLoading, setExportLoading] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getAdminAuditLog(limit);
      setLogs(data);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  }, [limit]);

  useEffect(() => {
    load();
  }, [load]);

  const handleExport = async (type, fn) => {
    setExportLoading(type);
    setMsg({ type: "", text: "" });
    try {
      const res = await fn();
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      const timestamps = new Date().toISOString().slice(0, 19).replace(/:/g, "-");
      a.download = `${type}_${timestamps}.${type === "analytics" ? "txt" : "csv"}`;
      a.click();
      URL.revokeObjectURL(url);
      setMsg({ type: "ok", text: `${type.charAt(0).toUpperCase() + type.slice(1)} exported successfully.` });
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setExportLoading(null);
    }
  };

  const filteredLogs = logs.filter(log =>
    log.action.toLowerCase().includes(filter.toLowerCase()) ||
    log.target_type.toLowerCase().includes(filter.toLowerCase()) ||
    log.admin_name.toLowerCase().includes(filter.toLowerCase()) ||
    (log.details && log.details.toLowerCase().includes(filter.toLowerCase()))
  );

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Admin Audit Log</h1>
        <p className="text-foreground/70">Track all administrative actions in the system.</p>
      </div>
      <Notice msg={msg} />

      <div className="grid gap-4 md:grid-cols-[1fr_380px]">
        <GlassCard>
          <CardHeader
            icon={<FileText className="h-5 w-5" />}
            title="Audit Log"
            description={`Showing ${filteredLogs.length} of ${logs.length} entries`}
            iconColor="primary"
            actions={
              <div className="flex items-center gap-2">
                <div className="relative">
                  <Search className="absolute left-2 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    placeholder="Filter logs…"
                    value={filter}
                    onChange={(e) => setFilter(e.target.value)}
                    className="pl-8 w-64"
                  />
                </div>
                <Button variant="outline" size="sm" onClick={() => { triggerRefreshAnimation(); load(); }} disabled={loading}>
                  <RefreshCw className={cn("h-4 w-4 mr-2", loading && "animate-spin")} />
                  Refresh
                </Button>
              </div>
            }
          />
          <div className="p-4 pt-0">
            {loading ? (
              <div className="flex items-center justify-center py-8">
                <Loader2 className="h-8 w-8 animate-spin text-primary" />
              </div>
            ) : filteredLogs.length === 0 ? (
              <EmptyState
                icon={<Filter className="h-12 w-12" />}
                title="No audit logs found"
                description="Try adjusting your filter or refresh the page."
              />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border text-left text-muted-foreground">
                      <th className="pb-2 pr-4">Time</th>
                      <th className="pb-2 pr-4">Admin</th>
                      <th className="pb-2 pr-4">Action</th>
                      <th className="pb-2 pr-4">Target</th>
                      <th className="pb-2 pr-4">Details</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredLogs.map((log) => (
                      <tr key={log.log_id} className="border-b border-border/50 hover:bg-muted/50">
                        <td className="py-2 pr-4 text-muted-foreground">
                          {format(new Date(log.created_at), "MMM d, yyyy HH:mm:ss")}
                        </td>
                        <td className="py-2 pr-4 font-medium">{log.admin_name}</td>
                        <td className="py-2 pr-4">
                          <StatusPill tone={getActionTone(log.action)}>{log.action}</StatusPill>
                        </td>
                        <td className="py-2 pr-4">
                          <span className="font-mono text-muted-foreground">{log.target_type} #{log.target_id}</span>
                        </td>
                        <td className="py-2 pr-4 text-muted-foreground max-w-xs truncate">
                          {log.details || "—"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </GlassCard>

        <GlassCard>
          <CardHeader
            icon={<Download className="h-5 w-5" />}
            title="Export Data"
            description="Download system data as CSV (or text for analytics)."
            iconColor="primary"
          />
          <div className="p-4 pt-0 grid gap-3">
            <ExportButton label="Export Users" icon={FileSpreadsheet} type="users" fn={exportUsersCSV} exportLoading={exportLoading} onExport={handleExport} />
            <ExportButton label="Export Applications" icon={FileSpreadsheet} type="applications" fn={exportApplicationsCSV} exportLoading={exportLoading} onExport={handleExport} />
            <ExportButton label="Export Bookings" icon={FileSpreadsheet} type="bookings" fn={exportBookingsCSV} exportLoading={exportLoading} onExport={handleExport} />
            <ExportButton label="Export Analytics Report" icon={FileText} type="analytics" fn={exportAnalyticsReport} exportLoading={exportLoading} onExport={handleExport} />
          </div>
        </GlassCard>
      </div>
    </>
  );
}