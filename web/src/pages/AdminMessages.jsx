import { useCallback, useEffect, useRef, useState } from "react";
import { Inbox, RefreshCw, Send } from "lucide-react";
import { getAdminMessageThreads, getAdminMessages, getChatActivity, sendAdminMessage, updateChatActivity } from "@/api";
import { useOutletContext, useSearchParams } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Notice } from "@/components/ui/alert";
import { EmptyState, GlassCard, PersonChip } from "@/components/ui/bento";
import { cn } from "@/lib/utils";
import { messageLanguageLabel } from "@/lib/messageMetadata";

export default function AdminMessages() {
  const { user, refresh, triggerRefreshAnimation } = useOutletContext();
  const [searchParams] = useSearchParams();
  const notificationApplicationId = Number(searchParams.get("application")) || null;
  const notificationMessageId = Number(searchParams.get("message")) || null;
  const [threads, setThreads] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [activity, setActivity] = useState({ is_online: false, is_typing: false });
  const [draft, setDraft] = useState("");
  const [loadingThreads, setLoadingThreads] = useState(true);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const bottomRef = useRef(null);
  const messageListRef = useRef(null);
  const messagesRef = useRef([]);
  const messageRefs = useRef(new Map());
  const deepLinkApplied = useRef(false);
  const focusedNotificationRef = useRef(false);
  const shouldScrollToLatestRef = useRef(false);
  const forceScrollToLatestRef = useRef(false);
  const typingRef = useRef(false);

  const loadThreads = useCallback(async () => {
    try {
      const data = await getAdminMessageThreads();
      setThreads(data);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoadingThreads(false);
    }
  }, []);

  const loadMessages = useCallback(async (applicationId) => {
    if (!applicationId) return;
    setLoadingMessages(true);
    try {
      const data = await getAdminMessages(applicationId, 100, notificationMessageId);
      const previous = messagesRef.current;
      const previousLatestId = previous.reduce((latest, message) => Math.max(latest, message.message_id), 0);
      const nextLatestId = data.messages.reduce((latest, message) => Math.max(latest, message.message_id), 0);
      const container = messageListRef.current;
      const wasAtBottom = !previous.length || !container
        || container.scrollHeight - container.scrollTop - container.clientHeight < 80;
      shouldScrollToLatestRef.current = forceScrollToLatestRef.current
        || !previous.length
        || (wasAtBottom && nextLatestId > previousLatestId);
      forceScrollToLatestRef.current = false;
      messagesRef.current = data.messages;
      setMessages(data.messages);
      setError("");
      refresh();
    } catch (e) {
      setError(e.message);
    } finally {
      setLoadingMessages(false);
    }
  }, [notificationMessageId, refresh]);

  useEffect(() => {
    loadThreads();
    const timer = setInterval(loadThreads, 15000);
    return () => clearInterval(timer);
  }, [loadThreads]);

  useEffect(() => {
    if (!notificationApplicationId || !threads.length || deepLinkApplied.current) return;
    deepLinkApplied.current = true;
    if (threads.some((thread) => thread.application_id === notificationApplicationId)) {
      setSelectedId(notificationApplicationId);
    } else {
      setError("The flagged conversation is no longer available.");
    }
  }, [notificationApplicationId, threads]);

  useEffect(() => {
    messagesRef.current = [];
    focusedNotificationRef.current = false;
    shouldScrollToLatestRef.current = false;
    forceScrollToLatestRef.current = false;
  }, [selectedId]);

  useEffect(() => {
    if (!selectedId) return undefined;
    loadMessages(selectedId);
    updateChatActivity(selectedId, false).catch((e) => setError(e.message));
    const timer = setInterval(() => {
      loadMessages(selectedId);
      getChatActivity(selectedId)
        .then(setActivity)
        .catch((e) => setError(e.message));
      updateChatActivity(selectedId, typingRef.current)
        .catch((e) => setError(e.message));
    }, 5000);
    return () => {
      clearInterval(timer);
      updateChatActivity(selectedId, false).catch(() => {});
    };
  }, [loadMessages, selectedId]);

  useEffect(() => {
    if (notificationApplicationId === selectedId && !focusedNotificationRef.current) {
      const flagged = [...messages].reverse().find((message) => message.moderation_categories);
      const targetId = notificationMessageId || flagged?.message_id;
      const target = targetId ? messageRefs.current.get(targetId) : null;
      if (target) {
        focusedNotificationRef.current = true;
        shouldScrollToLatestRef.current = false;
        target.scrollIntoView({ behavior: "smooth", block: "center" });
        return;
      }
    }
    if (shouldScrollToLatestRef.current) {
      shouldScrollToLatestRef.current = false;
      bottomRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, notificationApplicationId, notificationMessageId, selectedId]);

  function changeDraft(value) {
    setDraft(value);
    const typing = Boolean(value.trim());
    if (typingRef.current !== typing) {
      typingRef.current = typing;
      if (selectedId) updateChatActivity(selectedId, typing).catch((e) => setError(e.message));
    }
  }

  async function send(e) {
    e.preventDefault();
    const body = draft.trim();
    if (!selectedId || !body || sending) return;
    setSending(true);
    setError("");
    typingRef.current = false;
    try {
      await updateChatActivity(selectedId, false);
      await sendAdminMessage(selectedId, body);
      setDraft("");
      forceScrollToLatestRef.current = true;
      await Promise.all([loadMessages(selectedId), loadThreads()]);
    } catch (e) {
      setError(e.message);
    } finally {
      setSending(false);
    }
  }

  const selected = threads.find((thread) => thread.application_id === selectedId);

  return (
    <>
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="grid gap-1">
          <h1 className="text-3xl font-extrabold tracking-tight">Messages</h1>
          <p className="text-foreground/70">Review and reply to student–adviser conversations.</p>
        </div>
        <Button variant="outline" size="sm" onClick={() => { triggerRefreshAnimation(); loadThreads(); }}><RefreshCw /> Refresh</Button>
      </div>
      <Notice msg={error ? { type: "error", text: error } : null} />
      <div className="grid min-h-[32rem] gap-4 lg:grid-cols-[minmax(16rem,.8fr)_minmax(0,1.5fr)]">
        <GlassCard className="flex max-h-[70vh] flex-col overflow-hidden p-0">
          <div className="border-b border-border/40 p-4">
            <h2 className="font-bold">Conversations</h2>
            <p className="text-xs text-muted-foreground">{threads.length} active conversation(s)</p>
          </div>
          <div className="grid content-start gap-1 overflow-y-auto p-2">
            {loadingThreads && threads.length === 0 && <p className="p-3 text-sm text-muted-foreground">Loading messages…</p>}
            {!loadingThreads && threads.length === 0 && (
              <EmptyState icon={<Inbox className="h-10 w-10" />} title="No conversations yet" description="Application messages will appear here." />
            )}
            {threads.map((thread) => (
              <button
                key={thread.application_id}
                type="button"
                onClick={() => setSelectedId(thread.application_id)}
                className={cn(
                  "rounded-xl p-3 text-left transition-colors",
                  selectedId === thread.application_id ? "bg-primary/15" : "hover:bg-muted/70"
                )}
              >
                <div className="flex items-start justify-between gap-2">
                  <span className="truncate text-sm font-semibold">
                    {thread.student_name} <span className="font-normal text-muted-foreground">(Student)</span>
                    {" ↔ "}
                    {thread.adviser_name} <span className="font-normal text-muted-foreground">(Adviser)</span>
                  </span>
                  {thread.unread_count > 0 && <span className="rounded-full bg-primary px-2 py-0.5 text-xs font-bold text-primary-foreground">{thread.unread_count}</span>}
                </div>
                <p className="mt-1 truncate text-xs text-muted-foreground">{thread.topic_brief}</p>
                {thread.latest_flagged_categories && (
                  <p className="mt-2 text-xs font-semibold text-destructive">
                    Flagged for: {thread.latest_flagged_categories}
                  </p>
                )}
                <p className="mt-1 line-clamp-2 text-sm text-foreground/80">
                  {thread.latest_message_kind === "moderation_warning" ? "AdviserLink Moderation (Automated)" : thread.latest_sender_name}: {thread.latest_message}
                </p>
              </button>
            ))}
          </div>
        </GlassCard>

        <GlassCard className="flex max-h-[70vh] min-h-[32rem] flex-col overflow-hidden p-0">
          {!selected ? (
            <div className="grid flex-1 place-items-center p-6">
              <EmptyState icon={<Inbox className="h-12 w-12" />} title="Select a conversation" description="Choose a student–adviser conversation to view and reply." />
            </div>
          ) : (
            <>
              <div className="flex items-center gap-3 border-b border-border/40 p-4">
                <span className="relative shrink-0">
                  {selected.student_profile_photo
                    ? <img src={selected.student_profile_photo} alt="" className="h-10 w-10 rounded-full object-cover" />
                    : <span className="grid h-10 w-10 place-items-center rounded-full bg-primary/10 font-semibold text-primary">{selected.student_name?.split(" ").map((part) => part[0]).join("").slice(0, 2)}</span>}
                  {activity.is_online && <span title="A participant is online" aria-label="A participant is online" className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-background bg-emerald-500" />}
                </span>
                <PersonChip
                  name={`${selected.student_name} (Student)`}
                  subtitle={`with ${selected.adviser_name} (Adviser)${activity.is_typing ? " · Typing…" : activity.is_online ? " · Online" : ""}`}
                />
                <span className="ml-auto hidden max-w-[40%] truncate text-xs text-muted-foreground sm:block">{selected.topic_brief}</span>
              </div>
              <div ref={messageListRef} className="flex-1 space-y-3 overflow-y-auto p-4">
                {loadingMessages && messages.length === 0 && <p className="text-sm text-muted-foreground">Loading conversation…</p>}
                {messages.map((message) => {
                  const mine = message.sender_id === user.user_id;
                  const isAutomated = message.message_kind === "moderation_warning";
                  const senderRole = message.sender_id === selected.student_id
                    ? "Student"
                    : message.sender_id === selected.adviser_id ? "Adviser" : "Admin";
                  const languageLabel = messageLanguageLabel(message.language_code);
                  const isFlagged = Boolean(message.moderation_categories);
                  const isNotificationTarget = message.message_id === notificationMessageId;
                  return (
                    <div key={message.message_id} ref={(node) => {
                      if (node) messageRefs.current.set(message.message_id, node);
                      else messageRefs.current.delete(message.message_id);
                    }} className={cn("flex scroll-m-6 rounded-xl", (isNotificationTarget || (isFlagged && notificationApplicationId === selectedId)) && "ring-2 ring-destructive/70", mine ? "justify-end" : "justify-start")}>
                      <div className={cn("max-w-[85%] rounded-2xl px-4 py-2", mine ? "bg-primary text-primary-foreground" : "bg-muted")}>
                        <p className={cn("mb-1 text-xs font-semibold", mine ? "text-primary-foreground/75" : "text-muted-foreground")}>
                          {isAutomated ? "AdviserLink Moderation (Automated)" : mine ? "You (Admin)" : `${message.sender_name} (${senderRole})`}
                        </p>
                        {message.moderation_categories && (
                          <p className={cn("mb-1 text-xs font-semibold", mine ? "text-primary-foreground/85" : "text-destructive")}>
                            Flagged: {message.moderation_categories}
                          </p>
                        )}
                        <p className="whitespace-pre-wrap break-words text-sm">{message.body}</p>
                        {languageLabel && <p className={cn("mt-1 text-[10px]", mine ? "text-primary-foreground/70" : "text-muted-foreground")}>{languageLabel}</p>}
                        <div className={cn("mt-1 flex items-center justify-end gap-2 text-[10px]", mine ? "text-primary-foreground/70" : "text-muted-foreground")}>
                          <time>{new Date(message.created_at).toLocaleString()}</time>
                          {mine && !isAutomated && (
                            <span aria-label={message.read_at ? "Seen" : message.delivered_at ? "Delivered" : "Sent"}>
                              {message.read_at || message.is_read ? "Seen" : message.delivered_at ? "Delivered" : "Sent"}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
                <div ref={bottomRef} />
              </div>
              <form onSubmit={send} className="flex gap-2 border-t border-border/40 p-3">
                <textarea
                  value={draft}
                  onChange={(e) => changeDraft(e.target.value)}
                  onBlur={() => {
                    if (typingRef.current) {
                      typingRef.current = false;
                      updateChatActivity(selectedId, false).catch((e) => setError(e.message));
                    }
                  }}
                  maxLength={5000}
                  rows={2}
                  placeholder="Reply to this conversation…"
                  aria-label="Message"
                  className="min-h-11 flex-1 resize-y rounded-xl border border-input bg-background px-3 py-2 text-sm text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
                />
                <Button type="submit" disabled={sending || !draft.trim()} aria-label="Send message" className="self-end">
                  <Send className="h-4 w-4" /> Send
                </Button>
              </form>
            </>
          )}
        </GlassCard>
      </div>
    </>
  );
}
