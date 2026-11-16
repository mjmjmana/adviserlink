import { useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { CheckCircle, AlertCircle, Loader2, Mail, Copy } from "lucide-react";
import { verifyEmail, resendVerification, getDevToken } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import AuthShell from "./AuthShell";

export default function VerifyEmail() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get("token");
  const [status, setStatus] = useState("loading");
  const [message, setMessage] = useState("");
  const [email, setEmail] = useState("");
  const [devToken, setDevToken] = useState("");
  const [showDevToken, setShowDevToken] = useState(false);

  useEffect(() => {
    if (!token) {
      setStatus("error");
      setMessage("Invalid verification link. No token provided.");
      return;
    }
    verifyEmail(token)
      .then((res) => {
        setStatus("success");
        setMessage(res.message);
      })
      .catch((err) => {
        setStatus("error");
        setMessage(err.message);
      });
  }, [token]);

  async function handleResend(e) {
    e.preventDefault();
    try {
      const res = await resendVerification(email);
      setMessage(res.message);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function handleGetDevToken(e) {
    e.preventDefault();
    try {
      const res = await getDevToken(email || new URLSearchParams(window.location.search).get("email") || "");
      setDevToken(res.url);
      setShowDevToken(true);
    } catch (err) {
      setMessage(err.message);
    }
  }

  async function copyDevToken() {
    await navigator.clipboard.writeText(devToken);
    setMessage("Verification link copied to clipboard!");
  }

  return (
    <AuthShell title="Verify your email" subtitle={status === "loading" ? "Checking your verification link…" : ""}>
      {status === "loading" && (
        <div className="flex items-center justify-center gap-2 py-8">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
          <span>Verifying…</span>
        </div>
      )}
      {status === "success" && (
        <>
          <div className="flex items-center justify-center gap-2 text-success mb-4">
            <CheckCircle className="h-8 w-8" />
            <span className="text-xl font-bold">Email verified!</span>
          </div>
          <Notice msg={{ type: "ok", text: message }} />
          <p className="text-center text-sm">You can now <Link to="/login" className="font-bold text-primary">log in</Link>.</p>
        </>
      )}
      {status === "error" && (
        <>
          <div className="flex items-center justify-center gap-2 text-destructive mb-4">
            <AlertCircle className="h-8 w-8" />
            <span className="text-xl font-bold">Verification failed</span>
          </div>
          <Notice msg={{ type: "error", text: message }} />
          <form onSubmit={handleResend} className="grid gap-3 max-w-md mx-auto">
            <p className="text-center text-sm text-muted-foreground">Request a new verification link:</p>
            <div className="grid gap-1.5">
              <Label htmlFor="resend-email">Email</Label>
              <Input id="resend-email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
            </div>
            <Button type="submit">Resend verification email</Button>
          </form>

          {/* Dev mode: Get verification token directly */}
          <div className="mt-6 rounded-xl border border-border bg-muted/50 p-4">
            <p className="text-sm text-muted-foreground mb-3 text-center flex items-center justify-center gap-1">
              <Mail className="h-4 w-4" /> SMTP not configured? Get your verification link directly:
            </p>
            <form onSubmit={handleGetDevToken} className="grid gap-2">
              <Input type="email" placeholder="Enter your registered email" value={email} onChange={(e) => setEmail(e.target.value)} required />
              <Button type="submit" variant="outline">Get verification link (dev mode)</Button>
            </form>
            {showDevToken && devToken && (
              <div className="mt-3 grid gap-2">
                <div className="flex gap-2">
                  <Input value={devToken} readOnly className="flex-1" />
                  <Button variant="ghost" size="icon" onClick={copyDevToken} title="Copy to clipboard" className="h-9 w-9">
                    <Copy className="h-4 w-4" />
                  </Button>
                </div>
                <p className="text-xs text-muted-foreground text-center">
                  Click the link above or copy it to verify your email
                </p>
              </div>
            )}
          </div>

          <p className="text-center text-sm mt-4">Back to <Link to="/login" className="font-bold text-primary">Log in</Link></p>
        </>
      )}
    </AuthShell>
  );
}