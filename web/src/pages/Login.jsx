import { useState } from "react";
import { useLocation } from "react-router-dom";
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

  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(loginSchema),
    defaultValues: { email: "", password: "" },
  });

  async function onSubmit(data) {
    setError("");
    try {
      const res = await loginUser(data);
      saveToken(res.token);
      onLogin(res.user);
    } catch (err) {
      setError(err.message);
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
      {notice && !error && <Notice msg={{ type: "ok", text: notice }} />}
      {error && <Notice msg={{ type: "error", text: error }} />}
      <form onSubmit={handleSubmit(onSubmit)} className="grid gap-4">
        <div className="grid gap-1.5">
          <Label htmlFor="email">Email</Label>
          <Input id="email" type="email" {...register("email")} required autoComplete="email" aria-invalid={errors.email ? "true" : "false"} />
          {errors.email && <p className="text-sm text-destructive" role="alert">{errors.email.message}</p>}
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor="password">Password</Label>
          <Input id="password" type="password" {...register("password")} required autoComplete="current-password" aria-invalid={errors.password ? "true" : "false"} />
          {errors.password && <p className="text-sm text-destructive" role="alert">{errors.password.message}</p>}
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