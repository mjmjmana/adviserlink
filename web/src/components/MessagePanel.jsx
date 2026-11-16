import { useCallback, useEffect, useRef, useState } from "react";
import { Send, Loader2, Paperclip, X, User } from "lucide-react";
import { getChatActivity, getMessages, markMessagesRead, sendMessage, updateChatActivity } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { messageLanguageLabel } from "@/lib/messageMetadata";

function MessageItem({ msg, user }) {
  const isAutomated = msg.message_kind === "moderation_warning";
  const isMine = msg.sender_id === user.user_id && !isAutomated;
  const senderRole = msg.sender_role ? `${msg.sender_role[0].toUpperCase()}${msg.sender_role.slice(1)}` : "";
  const senderLabel = isAutomated
    ? "AdviserLink Moderation (Automated)"
    : isMine
      ? `You (${user.role[0].toUpperCase()}${user.role.slice(1)})`
      : `${msg.sender_name}${senderRole ? ` (${senderRole})` : ""}`;
  const languageLabel = messageLanguageLabel(msg.language_code);
  const avatarName = isAutomated ? "AdviserLink Moderation" : msg.sender_name;
  const getInitials = (name) => name?.split(" ").map(n => n[0]).join("").toUpperCase().slice(0, 2) || "?";
  const avatar = isAutomated ? null : isMine ? user.profile_photo : msg.sender_profile_photo;
  const deliveryStatus = msg.read_at || msg.is_read ? "Seen" : msg.delivered_at ? "Delivered" : "Sent";
  return (
    <div className={cn("flex gap-2 mb-3", isMine && "flex-row-reverse")}>
      {!isMine && (
        avatar ? (
          <img src={avatar} alt="" className="h-8 w-8 shrink-0 rounded-full object-cover" />
        ) : (
          <div className="h-8 w-8 shrink-0 rounded-full bg-primary/20 flex items-center justify-center text-primary font-medium text-sm">
            {getInitials(avatarName)}
          </div>
        )
      )}
      <div className={cn("max-w-[70%] flex flex-col", isMine && "items-end")}>
        <div className={cn(
          "rounded-2xl px-4 py-2 text-sm",
          isMine
            ? "bg-primary text-primary-foreground rounded-tr-sm"
            : "bg-muted text-foreground rounded-tl-sm"
        )}>
          <p className={cn("mb-0.5 text-xs font-semibold", isMine ? "text-primary-foreground/75" : "text-muted-foreground")}>{senderLabel}</p>
          <p className="whitespace-pre-wrap break-words">{msg.body}</p>
          {languageLabel && <p className={cn("mt-1 text-[10px]", isMine ? "text-primary-foreground/70" : "text-muted-foreground")}>{languageLabel}</p>}
        </div>
        <p className={cn("text-xs text-muted-foreground mt-1 px-1", isMine && "text-right")}>
          {new Date(msg.created_at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
          {isMine && !isAutomated && <span className="ml-2">{deliveryStatus}</span>}
        </p>
      </div>
      {isMine && (
        user.profile_photo ? (
          <img src={user.profile_photo} alt="" className="h-8 w-8 shrink-0 rounded-full object-cover" />
        ) : (
          <div className="h-8 w-8 shrink-0 rounded-full bg-primary/20 flex items-center justify-center text-primary font-medium text-sm">
            {getInitials(user.name)}
          </div>
        )
      )}
    </div>
  );
}

export function MessagePanel({ applicationId, user, contact, onUnreadChange, canSend = true, targetMessageId = null }) {
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [show, setShow] = useState(true);
  const [activity, setActivity] = useState({ is_online: false, is_typing: false });
  const endRef = useRef(null);
  const messageRefs = useRef(new Map());
  const focusedTargetRef = useRef(false);
  const loadRef = useRef(false);
  const messageCountRef = useRef(0);
  const typingRef = useRef(false);
  const typingDebounceRef = useRef(null);

  const publishActivity = useCallback(async (typing) => {
    typingRef.current = typing;
    try {
      await updateChatActivity(applicationId, typing);
    } catch (e) {
      setError(e.message);
    }
  }, [applicationId]);

  const load = useCallback(async ({ silent = false } = {}) => {
    if (!applicationId) return;
    try {
      const data = await getMessages(applicationId, targetMessageId ? 200 : 50, targetMessageId);
      const unread = data.filter(m => m.sender_id !== user.user_id && !m.is_read && !m.read_at);
      const latestId = data.reduce((latest, message) => Math.max(latest, message.message_id), 0);
      setMessages((current) => JSON.stringify(current) === JSON.stringify(data) ? current : data);
      if (onUnreadChange) onUnreadChange(unread.length);
      loadRef.current = true;
      if (data.length > messageCountRef.current && !targetMessageId) setTimeout(() => endRef.current?.scrollIntoView({ behavior: "smooth" }), 0);
      messageCountRef.current = data.length;
      if (latestId && unread.length) {
        await markMessagesRead(applicationId, latestId);
        const now = new Date().toISOString();
        setMessages((current) => current.map((message) =>
          message.sender_id !== user.user_id && message.message_id <= latestId
            ? { ...message, is_read: 1, delivered_at: message.delivered_at || now, read_at: message.read_at || now }
            : message
        ));
        if (onUnreadChange) onUnreadChange(0);
      }
      if (!silent) setError("");
    } catch (e) {
      setError(e.message);
    }
  }, [applicationId, targetMessageId, user.user_id, onUnreadChange]);

  const refreshActivity = useCallback(async () => {
    try {
      setActivity(await getChatActivity(applicationId));
    } catch (e) {
      setError(e.message);
    }
  }, [applicationId]);

  useEffect(() => {
    load();
    publishActivity(false);
    const timer = setInterval(() => {
      load({ silent: true });
      refreshActivity();
      publishActivity(typingRef.current);
    }, 5000);
    return () => {
      clearInterval(timer);
      clearTimeout(typingDebounceRef.current);
    };
  }, [load, publishActivity, refreshActivity]);

  useEffect(() => {
    if (!targetMessageId || focusedTargetRef.current) return;
    const target = messageRefs.current.get(targetMessageId);
    if (!target) return;
    focusedTargetRef.current = true;
    target.scrollIntoView({ behavior: "smooth", block: "center" });
  }, [messages, targetMessageId]);

  const handleTextChange = (value) => {
    setText(value);
    clearTimeout(typingDebounceRef.current);
    if (!value.trim()) {
      publishActivity(false);
      return;
    }
    typingDebounceRef.current = setTimeout(() => publishActivity(true), 250);
  };

  const handleSend = async (e) => {
    e.preventDefault();
    if (!text.trim() || sending) return;
    setSending(true);
    setError("");
    clearTimeout(typingDebounceRef.current);
    await publishActivity(false);
    try {
      await sendMessage(applicationId, text.trim());
      setText("");
      await load();
    } catch (e) {
      setError(e.message);
    } finally {
      setSending(false);
    }
  };

  if (!show) {
    return (
      <Button variant="ghost" size="sm" className="gap-1" onClick={() => setShow(true)}>
        <Paperclip className="h-4 w-4" /> Messages
        {messages.filter(m => m.sender_id !== user.user_id && !m.is_read).length > 0 && (
          <Badge variant="destructive" className="ml-1">
            {messages.filter(m => m.sender_id !== user.user_id && !m.is_read).length}
          </Badge>
        )}
      </Button>
    );
  }

  return (
    <div className="flex flex-col h-full border-l border-border bg-muted">
      <div className="p-3 border-b border-border flex items-center justify-between">
        <div className="flex min-w-0 items-center gap-2">
          {contact && (
            <span className="relative shrink-0">
              {contact.profile_photo ? (
                <img src={contact.profile_photo} alt="" className="h-9 w-9 rounded-full object-cover" />
              ) : (
                <span className="grid h-9 w-9 place-items-center rounded-full bg-primary/20 text-sm font-semibold text-primary">
                  {contact.name?.split(" ").map((part) => part[0]).join("").slice(0, 2).toUpperCase() || <User className="h-4 w-4" />}
                </span>
              )}
              {activity.is_online && <span title="Online" aria-label="Online" className="absolute bottom-0 right-0 h-3 w-3 rounded-full border-2 border-muted bg-emerald-500" />}
            </span>
          )}
          <div className="min-w-0">
            <h3 className="truncate font-semibold">{contact?.name || "Messages"}</h3>
            <p className="text-xs text-muted-foreground">
              {activity.is_typing ? "Typing…" : activity.is_online ? "Online" : "Offline"}
            </p>
          </div>
        </div>
        <Button variant="ghost" size="icon" onClick={() => setShow(false)}><X className="h-4 w-4" /></Button>
      </div>
      <div className="flex-1 p-3 overflow-y-auto">
        {messages.length === 0 ? (
          <p className="text-center text-muted-foreground py-8">{canSend ? "No messages yet. Start the conversation!" : "No messages yet."}</p>
        ) : (
          messages.map((m) => (
            <div
              key={m.message_id}
              ref={(node) => {
                if (node) messageRefs.current.set(m.message_id, node);
                else messageRefs.current.delete(m.message_id);
              }}
              className={cn(targetMessageId === m.message_id && "rounded-2xl ring-2 ring-primary/70")}
            >
              <MessageItem msg={m} user={user} />
            </div>
          ))
        )}
        {activity.is_typing && (
          <div className="mb-3 flex items-center gap-2 text-xs text-muted-foreground" role="status" aria-label={`${contact?.name || "The other person"} is typing`}>
            <span>{contact?.name || "The other person"} is typing</span>
            <span className="flex gap-1">
              {[0, 1, 2].map((dot) => <span key={dot} className="h-1.5 w-1.5 animate-bounce rounded-full bg-primary" style={{ animationDelay: `${dot * 120}ms` }} />)}
            </span>
          </div>
        )}
        <div ref={endRef} />
      </div>
      {error && <div className="p-3 text-sm text-destructive border-t border-border">{error}</div>}
      {canSend ? (
        <form onSubmit={handleSend} className="p-3 border-t border-border flex gap-2">
          <Input
            value={text}
            onChange={(e) => handleTextChange(e.target.value)}
            onBlur={() => publishActivity(false)}
            placeholder="Type a message…"
            maxLength={2000}
            disabled={sending}
            className="flex-1"
          />
          <Button type="submit" disabled={sending || !text.trim()} size="icon">
            {sending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Send className="h-4 w-4" />}
          </Button>
        </form>
      ) : (
        <p className="border-t border-border p-3 text-center text-xs text-muted-foreground">Only the group leader can message the adviser.</p>
      )}
    </div>
  );
}

export default MessagePanel;
