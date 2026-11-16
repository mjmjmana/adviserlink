import { useState } from "react";
import { useLocation } from "react-router-dom";
import { Eye, EyeOff } from "lucide-react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { loginUser, saveToken, resendVerification } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import AuthShell from "./AuthShell";

const loginSchema = z.object({
  email: z.string().email("Enter a valid email address"),
  password: z.string().min(1, "Password is required"),
});

export default function Login({ onLogin }) {
  const location = useLocation();
  const notice = location.state && location.state.notice;
  const [error, setError] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [credentialError, setCredentialError] = useState(false);

  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  function clearCredentialError() {
    if (!error && !credentialError) return;
    setError("");
    setCredentialError(false);
  }

  async function onSubmit(data) {
    setError("");
    setCredentialError(false);
    try {
      const res = await loginUser(data);
      saveToken(res.token);
      onLogin(res.user);
    } catch (err) {
      if (err.message.toLowerCase() === "incorrect email or password.") {
        setCredentialError(true);
      } else {
        setError(err.message);
      }
    }
  }

  async function handleResend(e) {
    e.preventDefault();
    try {
      const res = await resendVerification(location.state?.email || "");
      setError(res.message);
    } catch (err) {
      setError(err.message);
    }
  }

  const isEmailNotVerified = error && error.toLowerCase().includes("verify");

  return (
    <AuthShell title="Welcome back" subtitle="Log in to continue to AdviserLink.">
      {notice && !error && !credentialError && <Notice msg={{ type: "ok", text: notice }} />}
      {error && !credentialError && <Notice msg={{ type: "error", text: error }} />}
      <form noValidate onSubmit={handleSubmit(onSubmit)} className="grid gap-4">
        <div className="grid gap-1.5">
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" {...register("email", { onChange: clearCredentialError })} required autoComplete="email" error={errors.email?.message} className={credentialError ? "border-destructive focus:border-destructive focus:ring-destructive/30" : ""} aria-invalid={errors.email || credentialError ? "true" : "false"} />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="password">Password</Label>
          <div className="relative">
            <Input id="password" type={showPassword ? "text" : "password"} className={`pr-11 ${credentialError ? "border-destructive focus:border-destructive focus:ring-destructive/30" : ""}`} {...register("password", { onChange: clearCredentialError })} required autoComplete="current-password" error={errors.password?.message} aria-invalid={errors.password || credentialError ? "true" : "false"} />
            <button type="button" onClick={() => setShowPassword((visible) => !visible)} aria-label={showPassword ? "Hide password" : "Show password"} aria-pressed={showPassword} className="absolute inset-y-0 right-0 inline-flex items-center px-3 text-muted-foreground hover:text-foreground">
              {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>
          {credentialError && <p className="text-sm text-destructive" role="alert">Incorrect email or password.</p>}
        </div>
        <Button type="submit" disabled={isSubmitting} className="mt-2">{isSubmitting ? "Logging in…" : "Log in"}</Button>
      </form>
      {isEmailNotVerified && (
        <form onSubmit={handleResend} className="grid gap-2 text-center text-sm">
          <p className="text-muted-foreground">Didn't receive the verification email?</p>
          <Button type="submit" variant="ghost" size="sm">Resend verification email</Button>
        </form>
      )}
    </AuthShell>
  );
}