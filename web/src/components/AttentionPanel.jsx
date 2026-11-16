import { useCallback, useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { AlertTriangle, CheckCircle2, Info } from "lucide-react";
import { getAttention, nudgeAdvisee } from "@/api";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

const ICON = { warn: [AlertTriangle, "bg-secondary text-secondary-foreground"], info: [Info, "bg-secondary text-secondary-foreground"] };

// "Needs your attention": ang mga dapat gawin ngayon, may kasamang isang-click na action.
export default function AttentionPanel({ reloadKey, onBook, onRate, onMessage }) {
  const [items, setItems] = useState(null);
  const navigate = useNavigate();
  const load = useCallback(() => getAttention().then(setItems).catch(() => setItems([])), []);
  useEffect(() => { load(); }, [load, reloadKey]);

  async function act(a) {
    if (a.type === "book") onBook();
    else if (a.type === "rate") onRate(a.booking_id);
    else if (a.type === "nudge") {
      try { await nudgeAdvisee(a.application_id); onMessage({ type: "ok", text: "Reminder sent." }); load(); }
      catch (e) { onMessage({ type: "error", text: e.message }); }
    }
  }

  if (items === null) return null;
  return (
    <Card>
      <CardHeader className="pb-2"><CardTitle className="text-lg">Needs your attention</CardTitle></CardHeader>
      <CardContent className="grid gap-2 pt-1">
        {items.length === 0 && (
          <p className="flex items-center gap-2 text-sm text-muted-foreground"><CheckCircle2 className="h-4 w-4 text-success" /> You're all caught up. Nothing needs action right now.</p>
        )}
        {items.map((it) => {
          const [Icon, cls] = ICON[it.level] || ICON.info;
          return (
            <div key={it.id} className="flex items-center gap-3 rounded-2xl bg-secondary text-secondary-foreground px-3 py-2.5">
              <span className={cn("grid h-8 w-8 shrink-0 place-items-center rounded-full", cls)}><Icon className="h-4 w-4" /></span>
              <span className="flex-1 text-sm font-medium leading-snug">{it.text}</span>
              {it.action && it.action.type === "link" && (
                <Button size="sm" variant="secondary" onClick={() => navigate(it.action.to)}>{it.action.label}</Button>
              )}
              {it.action && it.action.type !== "link" && <Button size="sm" onClick={() => act(it.action)}>{it.action.label}</Button>}
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}
