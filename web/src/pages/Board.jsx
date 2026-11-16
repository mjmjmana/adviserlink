import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useOutletContext, useSearchParams } from "react-router-dom";
import { ChevronLeft, ChevronRight, Download, Eye, FileText, Loader2, MessageSquare, Paperclip, Trash2 } from "lucide-react";
import { addComment, addTask, deleteDoc, deleteTask, downloadDoc, getBoard, listDocs, myApplications, patchTask, previewDoc, uploadDoc } from "@/api";
import { MessagePanel } from "@/components/MessagePanel";
import { DocumentVersions } from "@/components/DocumentVersions";
import { PersonChip, StatusPill } from "@/components/ui/bento";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { GlassCard, CardHeader, InfoRow } from "@/components/ui/bento";
import { Input } from "@/components/ui/input";
import { Notice } from "@/components/ui/alert";
import { Progress } from "@/components/ui/progress";
import { Select } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { fmtDateLong, fmtSize, parseYmd } from "@/lib/dates";

const COLUMNS = [
  { key: "todo", label: "To Do" },
  { key: "in_progress", label: "In Progress" },
  { key: "review", label: "For Review" },
  { key: "done", label: "Done" },
];

const STATUS_TONES = {
  todo: "default",
  in_progress: "info",
  review: "warning",
  done: "success",
};

function canMoveTask(task, target, isAdviser, canManage) {
  if (!canManage) return false;
  if (isAdviser) return task.status === "review" && ["in_progress", "done"].includes(target);
  if (task.status === "todo") return target === "in_progress";
  if (task.status === "in_progress") return target === "review" && (task.has_documents || (task.documents || []).length > 0);
  return false;
}

function TaskCard({ task, isAdviser, canManage, canComment, commentDraft, onDraftChange, userId, onMove, onDelete, onComment, onUpload, onPreview, onDownload, onDeleteDoc }) {
  const text = commentDraft?.text || "";
  const attachment = commentDraft?.attachment || null;
  const commentFileRef = useRef(null);
  const idx = COLUMNS.findIndex((c) => c.key === task.status);
  const prev = COLUMNS[idx - 1], next = COLUMNS[idx + 1];
  const prevBlocked = !prev || !canMoveTask(task, prev.key, isAdviser, canManage);
  const nextBlocked = !next || !canMoveTask(task, next.key, isAdviser, canManage);
  const dueDate = task.due_date ? parseYmd(task.due_date) : null;
  const overdue = dueDate && dueDate < new Date(new Date().setHours(0, 0, 0, 0)) && task.status !== "done";

  return (
    <article className="grid gap-2 rounded-[var(--radius-card)] bg-muted/50 p-3 border border-border/20 text-[10px]" draggable onDragStart={(e) => e.dataTransfer.setData("text/plain", String(task.task_id))}>
      <div className="flex items-start justify-between gap-2">
        <strong className="text-[11px] leading-snug">{task.title}</strong>
      </div>
      {task.description && <p className="text-[10px] text-muted-foreground">{task.description}</p>}
      {dueDate && <small className={overdue ? "text-[10px] font-semibold text-destructive" : "text-[10px] text-muted-foreground"}>{overdue ? "Overdue · " : "Due · "}{fmtDateLong(dueDate)}</small>}
      <small className="text-[10px] text-muted-foreground">by {task.created_by_name}</small>
      {canManage && (
        <div className="flex items-center gap-1.5">
          <Button size="icon" variant="secondary" className="h-8 w-8" disabled={prevBlocked} onClick={() => onMove(task, prev.key)} aria-label={prev ? `Previous: ${prev.label}` : "Previous stage"}><ChevronLeft /></Button>
          <Button size="sm" variant="secondary" disabled={nextBlocked} title={!isAdviser && task.status === "in_progress" && !task.has_documents && !(task.documents || []).length ? "Attach your work before submitting for review" : ""} onClick={() => onMove(task, next.key)} aria-label={next ? `Next: ${next.label}` : "Next stage"}><ChevronRight />{next ? `Next: ${next.label}` : "Next"}</Button>
          {isAdviser && <Button size="icon" variant="ghost" className="ml-auto h-8 w-8 text-destructive" onClick={() => onDelete(task)} aria-label="Delete"><Trash2 /></Button>}
        </div>
      )}
      {canManage && !isAdviser && task.status === "in_progress" && (
        <Button size="sm" variant="outline" onClick={() => onUpload(task)}><Paperclip /> Attach work</Button>
      )}
      {(task.documents || []).length > 0 && (
        <div className="grid gap-1.5 border-t border-border/30 pt-2">
          <small className="font-bold">Task attachments</small>
          {task.documents.map((doc) => (
            <div key={doc.document_id} className="flex items-center gap-1.5 rounded-lg bg-background/60 px-2 py-1.5">
              <FileText className="h-4 w-4 shrink-0 text-muted-foreground" />
              <span className="min-w-0 flex-1 truncate" title={doc.filename}>{doc.filename}<small className="block text-muted-foreground">{fmtSize(doc.size_bytes)} · {doc.uploaded_by_name}</small></span>
              <Button size="icon" variant="ghost" className="h-7 w-7" aria-label={`Preview ${doc.filename}`} onClick={() => onPreview(doc)}><Eye /></Button>
              <Button size="icon" variant="ghost" className="h-7 w-7" aria-label={`Download ${doc.filename}`} onClick={() => onDownload(doc)}><Download /></Button>
              {!isAdviser && doc.uploaded_by === userId && task.status === "in_progress" && <Button size="icon" variant="ghost" className="h-7 w-7 text-destructive" aria-label={`Delete ${doc.filename}`} onClick={() => onDeleteDoc(doc)}><Trash2 /></Button>}
            </div>
          ))}
        </div>
      )}
      {task.comments.map((c) => (
        <div key={c.comment_id} className="grid gap-1 rounded-lg border-l-4 border-primary bg-muted/50 px-2.5 py-1.5 text-[10px]">
          <span><b>{c.author_name}</b> {c.body}</span>
          {c.attachment && (
            <div className="flex items-center gap-1.5 rounded-lg bg-background/60 px-2 py-1.5">
              <FileText className="h-4 w-4 shrink-0 text-muted-foreground" />
              <span className="min-w-0 flex-1 truncate" title={c.attachment.filename}>{c.attachment.filename}<small className="block text-muted-foreground">{fmtSize(c.attachment.size_bytes)} · {c.attachment.uploaded_by_name}</small></span>
              <Button size="icon" variant="ghost" className="h-7 w-7" aria-label={`Preview ${c.attachment.filename}`} onClick={() => onPreview(c.attachment)}><Eye /></Button>
              <Button size="icon" variant="ghost" className="h-7 w-7" aria-label={`Download ${c.attachment.filename}`} onClick={() => onDownload(c.attachment)}><Download /></Button>
            </div>
          )}
          <small className="text-muted-foreground">{c.created_at}</small>
        </div>
      ))}
      {canComment && (
        <form className="grid gap-1.5" onSubmit={async (e) => {
          e.preventDefault();
          if (!text.trim()) return;
          const sent = await onComment(task, text.trim(), attachment);
          if (sent) {
            onDraftChange(task.task_id, { text: "", attachment: null });
            if (commentFileRef.current) commentFileRef.current.value = "";
          }
        }}>
          <div className="flex gap-1.5">
            <Input className="h-8" value={text} onChange={(e) => onDraftChange(task.task_id, { text: e.target.value })} placeholder={isAdviser ? "Comment for the student…" : "Reply to your adviser…"} maxLength={2000} />
            <Button size="sm" type="submit" disabled={!text.trim()}>Send</Button>
          </div>
          <div className="flex items-center gap-2">
            <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-md border border-border/50 px-2 py-1 text-[10px] text-muted-foreground hover:bg-muted">
              <Paperclip className="h-3.5 w-3.5" />
              {attachment ? "Change file" : "Attach file (optional)"}
              <input ref={commentFileRef} type="file" className="sr-only" onChange={(e) => onDraftChange(task.task_id, { attachment: e.target.files?.[0] || null })} />
            </label>
            {attachment && (
              <>
                <span className="min-w-0 flex-1 truncate text-[10px] text-muted-foreground" title={attachment.name}>{attachment.name}</span>
                <Button type="button" size="sm" variant="ghost" className="h-6 px-1.5 text-[10px]" onClick={() => {
                  onDraftChange(task.task_id, { attachment: null });
                  if (commentFileRef.current) commentFileRef.current.value = "";
                }}>Remove</Button>
              </>
            )}
          </div>
        </form>
      )}
    </article>
  );
}

export default function Board() {
  const { user } = useOutletContext();
  const isAdviser = user.role === "adviser";
  const [params, setParams] = useSearchParams();
  const [activeTab, setActiveTab] = useState(() => params.get("message") ? "messages" : "board");
  const [apps, setApps] = useState([]);
  const [board, setBoard] = useState(null);
  const [docs, setDocs] = useState([]);
  const [commentDrafts, setCommentDrafts] = useState({});
  const [form, setForm] = useState({ title: "", description: "", due_date: "" });
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [preview, setPreview] = useState(null);
  const fileRef = useRef(null);
  const uploadTo = useRef("todo");
  const uploadTaskId = useRef(null);

  useEffect(() => {
    myApplications().then((all) => {
      const ok = all.filter((a) => a.status === "approved");
      setApps(ok);
      if (!params.get("app") && ok.length) setParams({ app: String(ok[0].application_id) }, { replace: true });
    }).catch((e) => setMsg({ type: "error", text: e.message }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const appId = params.get("app");
  const targetMessageId = Number(params.get("message")) || null;
  useEffect(() => {
    if (targetMessageId) setActiveTab("messages");
  }, [targetMessageId]);
  const canManage = Boolean(board?.can_manage);
  const updateCommentDraft = (taskId, changes) => setCommentDrafts((current) => ({
    ...current,
    [taskId]: { ...(current[taskId] || { text: "", attachment: null }), ...changes },
  }));
  const load = useCallback(() => {
    if (!appId) return;
    getBoard(appId).then(setBoard).catch((e) => setMsg({ type: "error", text: e.message }));
    listDocs(appId).then(setDocs).catch(() => {});
  }, [appId]);
  useEffect(() => { load(); }, [load]);

  const run = async (fn, okText) => {
    setMsg({ type: "", text: "" });
    try {
      await fn();
      if (okText) setMsg({ type: "ok", text: okText });
      load();
      return true;
    } catch (e) {
      setMsg({ type: "error", text: e.message });
      load();
      return false;
    }
  };
  const move = (task, status) => run(() => patchTask(task.task_id, { status }));
  useEffect(() => () => {
    if (preview?.url) URL.revokeObjectURL(preview.url);
  }, [preview]);

  // Ang upload ay nakakabit sa column na pinindot (To Do / In Progress / For Review)
  const pickFile = (key, taskId = null) => { uploadTo.current = key; uploadTaskId.current = taskId; fileRef.current.value = ""; fileRef.current.click(); };
  const onFile = (e) => {
    const f = e.target.files[0];
    if (f) run(() => uploadDoc(appId, f, uploadTo.current, uploadTaskId.current), uploadTaskId.current ? "Work attached to the task." : "Uploaded. Your adviser was notified.");
  };
  const openPreview = async (doc) => {
    const ext = doc.filename.split(".").pop().toLowerCase();
    if (!["pdf", "txt", "png", "jpg", "jpeg", "webp"].includes(ext)) {
      setPreview({ kind: "unsupported", doc });
      return;
    }
    try {
      const blob = await previewDoc(doc.document_id);
      setPreview(ext === "txt"
        ? { kind: "text", doc, text: await blob.text() }
        : { kind: "media", doc, url: URL.createObjectURL(blob), isImage: ["png", "jpg", "jpeg", "webp"].includes(ext) });
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
  };

  if (apps.length === 0) {
    return (
      <>
        <h1 className="text-3xl font-extrabold tracking-tight">Progress board</h1>
        <p className="text-foreground/70">The board opens once an application is approved. <Link className="font-bold text-primary" to="/home">Go back</Link></p>
      </>
    );
  }

  const pct = board && board.progress.total ? Math.round((board.progress.done / board.progress.total) * 100) : 0;
  const contact = board?.application ? {
    name: isAdviser ? board.application.student_name : board.application.adviser_name,
    profile_photo: isAdviser ? board.application.student_profile_photo : board.application.adviser_profile_photo,
  } : null;

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Progress board</h1>
        {apps.length > 1 ? (
          <Select className="w-auto max-w-xs" value={appId || ""} onChange={(e) => setParams({ app: e.target.value })}>
            {apps.map((a) => <option key={a.application_id} value={a.application_id}>{isAdviser ? a.student_name : a.adviser_name}</option>)}
          </Select>
        ) : null}
        {board && (
          <PersonChip
            avatar={isAdviser ? board.application.student_profile_photo : board.application.adviser_profile_photo}
            name={isAdviser ? board.application.student_name : board.application.adviser_name}
            subtitle={board.application.topic_brief}
          />
        )}
      </div>
      <Notice msg={msg} />

      {board && (
        <>
          <input ref={fileRef} type="file" className="hidden" onChange={onFile} />
          <Dialog open={Boolean(preview)} onOpenChange={(open) => { if (!open) setPreview(null); }}>
            <DialogContent className="max-w-4xl">
              <DialogHeader>
                <DialogTitle>{preview?.doc.filename}</DialogTitle>
                <DialogDescription>Task attachment · {preview?.doc.uploaded_by_name}</DialogDescription>
              </DialogHeader>
              {preview?.kind === "media" && (preview.isImage
                ? <img src={preview.url} alt={preview.doc.filename} className="max-h-[70vh] w-full rounded-lg object-contain" />
                : <iframe title={preview.doc.filename} src={preview.url} sandbox="allow-same-origin" className="h-[70vh] w-full rounded-lg border" />)}
              {preview?.kind === "text" && <pre className="max-h-[70vh] overflow-auto whitespace-pre-wrap rounded-lg bg-muted p-4 text-sm">{preview.text}</pre>}
              {preview?.kind === "unsupported" && (
                <div className="grid gap-3 text-sm text-muted-foreground">
                  <p>This file format cannot be previewed in the browser. Download it to open it in a compatible app.</p>
                  <Button variant="outline" onClick={() => downloadDoc(preview.doc.document_id, preview.doc.filename).catch((e) => setMsg({ type: "error", text: e.message }))}><Download /> Download file</Button>
                </div>
              )}
            </DialogContent>
          </Dialog>
          <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="board"><span>Board</span></TabsTrigger>
              <TabsTrigger value="messages"><span className="flex items-center gap-1"><MessageSquare className="h-4 w-4" /> Messages</span></TabsTrigger>
              <TabsTrigger value="documents"><span>Documents</span></TabsTrigger>
            </TabsList>

            <TabsContent value="board">
              <div className="grid items-stretch gap-4 lg:grid-cols-[2fr_3fr]">
                <GlassCard className="gap-2 p-5">
                  <div className="flex items-center justify-between"><b>Overall progress</b><span className="text-sm">{board.progress.done} / {board.progress.total} tasks · {pct}%</span></div>
                  <Progress value={pct} />
                  <small className="text-muted-foreground">{isAdviser
                    ? "Students move assigned tasks to In Progress, attach their work, and submit it For Review. Return work for revision or mark it Done."
                    : canManage
                      ? "Move assigned tasks to In Progress, attach your completed work, then submit it For Review. Your adviser will mark it Done."
                      : "You can view the group's board and files. Only the group leader can update tasks or submit work."}</small>
                </GlassCard>
                {isAdviser && <GlassCard className="p-5">
                  <form className="grid gap-2 sm:grid-cols-[minmax(0,1fr)_auto_auto]" onSubmit={(e) => { e.preventDefault(); run(async () => { await addTask(appId, { ...form, due_date: form.due_date || null }); setForm({ title: "", description: "", due_date: "" }); }); }}>
                    <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="New task (e.g. Draft Chapter 1)" required maxLength={150} />
                    <Input type="date" aria-label="Task due date" value={form.due_date} onChange={(e) => setForm({ ...form, due_date: e.target.value })} />
                    <Button type="submit">Add task</Button>
                  </form>
                </GlassCard>}
              </div>

              <div className="grid items-stretch gap-4 md:grid-cols-2 xl:grid-cols-4">
                {COLUMNS.map((col) => {
                  const tasks = board.tasks.filter((t) => t.status === col.key);
                  const files = docs.filter((d) => d.category === col.key && !d.task_id);
                  const tone = STATUS_TONES[col.key] || "default";
                  return (
                    <section
                      key={col.key}
                      className="grid content-start gap-3 rounded-[var(--radius-card)] bg-muted/30 p-3 border border-border/20"
                      onDragOver={(e) => e.preventDefault()}
                      onDrop={(e) => { const id = Number(e.dataTransfer.getData("text/plain")); const t = board.tasks.find((x) => x.task_id === id); if (t && canMoveTask(t, col.key, isAdviser, canManage)) move(t, col.key); }}
                    >
                      <div className="flex items-center justify-between gap-2 px-1">
                        <h3 className="flex items-center gap-2 text-[18px] font-bold">{col.label} <Badge variant="dark">{tasks.length}</Badge></h3>
                      </div>
                      {tasks.map((t) => (
                        <TaskCard key={t.task_id} task={t} isAdviser={isAdviser} canManage={canManage} canComment={board.can_comment}
                          commentDraft={commentDrafts[t.task_id]} onDraftChange={updateCommentDraft} userId={user.user_id} onMove={move}
                          onDelete={(task) => run(() => deleteTask(task.task_id))}
                          onComment={(task, body, file) => run(() => addComment(task.task_id, body, file), "Comment sent.")}
                          onUpload={(task) => pickFile("review", task.task_id)}
                          onPreview={openPreview}
                          onDownload={(doc) => downloadDoc(doc.document_id, doc.filename).catch((e) => setMsg({ type: "error", text: e.message }))}
                          onDeleteDoc={(doc) => run(() => deleteDoc(doc.document_id))} />
                      ))}
                      {files.length > 0 && (
                        <div className="grid gap-1.5 rounded-[var(--radius-card)] border border-dashed border-foreground/30 p-2.5 max-h-[300px] overflow-y-auto">
                          <small className="font-bold px-1">Files in {col.label}</small>
                          {files.map((d) => (
                            <div key={d.document_id} className="flex items-center gap-2 rounded-xl bg-muted/50 px-2.5 py-1.5 text-sm hover:bg-muted transition-colors">
                              <FileText className="h-4 w-4 shrink-0 text-muted-foreground" />
                              <span className="min-w-0 flex-1 truncate" title={d.filename}>{d.filename}<small className="block text-muted-foreground">{fmtSize(d.size_bytes)} · {d.uploaded_by_name}</small></span>
                              <Button size="icon" variant="ghost" className="h-7 w-7" aria-label="Download" onClick={() => downloadDoc(d.document_id, d.filename).catch((e) => setMsg({ type: "error", text: e.message }))}><Download /></Button>
                              {canManage && !isAdviser && d.uploaded_by === user.user_id && <Button size="icon" variant="ghost" className="h-7 w-7 text-destructive" aria-label="Delete file" onClick={() => run(() => deleteDoc(d.document_id))}><Trash2 /></Button>}
                            </div>
                          ))}
                        </div>
                      )}
                    </section>
                  );
                })}
              </div>
            </TabsContent>

            <TabsContent value="messages">
              <MessagePanel applicationId={appId} user={user} contact={contact} canSend={canManage || isAdviser} targetMessageId={targetMessageId} />
            </TabsContent>

            <TabsContent value="documents">
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {docs.length === 0 ? (
                  <GlassCard className="p-8 text-center border-dashed col-span-full">
                    <FileText className="h-12 w-12 mx-auto text-muted-foreground/50" />
                    <p className="mt-4 text-muted-foreground">No documents yet.</p>
                  </GlassCard>
                ) : (
                  docs.map((d) => (
                    <GlassCard key={d.document_id} className="p-4 flex flex-col">
                      <div className="flex items-start gap-3 mb-3">
                        <div className="flex-shrink-0 w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
                          <FileText className="h-5 w-5 text-primary" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="font-medium truncate" title={d.filename}>{d.filename}</p>
                          <p className="text-sm text-muted-foreground">{fmtSize(d.size_bytes)} · {d.uploaded_by_name}</p>
                          <StatusPill tone="default" variant="outline" size="sm">{d.category}</StatusPill>
                        </div>
                      </div>
                      <div className="mt-auto pt-3 border-t border-border/30">
                        <DocumentVersions documentId={d.document_id} user={user} canUpload={canManage} onUpload={load} />
                      </div>
                    </GlassCard>
                  ))
                )}
              </div>
            </TabsContent>
          </Tabs>
        </>
      )}
    </>
  );
}