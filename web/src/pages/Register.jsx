import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { registerUser } from "@/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { BookOpenCheck, Eye, EyeOff, GraduationCap, UserRound, X } from "lucide-react";
import { ADVISER_DEPARTMENTS } from "@/constants/adviserDepartments";
import AuthShell from "./AuthShell";

const registerSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  confirm_password: z.string().min(1, "Please confirm your password"),
  role: z.enum(["student", "adviser"]),
  student_group_role: z.enum(["leader", "member"]),
  department: z.string().optional(),
}).refine((data) => data.password === data.confirm_password, {
  message: "The two passwords do not match.",
  path: ["confirm_password"],
}).refine((data) => data.role !== "adviser" || ADVISER_DEPARTMENTS.includes(data.department), {
  message: "Choose your department.",
  path: ["department"],
});

export default function Register() {
  const navigate = useNavigate();
  const [error, setError] = useState("");
  const [successMessage, setSuccessMessage] = useState("");
  const [roleSwitchDirection, setRoleSwitchDirection] = useState("right");
  const [profilePhoto, setProfilePhoto] = useState("");
  const [photoError, setPhotoError] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const { register, handleSubmit, formState: { errors, isSubmitting }, watch, setValue } = useForm({
    resolver: zodResolver(registerSchema),
    defaultValues: { name: "", email: "", password: "", confirm_password: "", role: "student", student_group_role: "leader", department: "" },
  });

  const role = watch("role");

  function switchRole(nextRole) {
    if (nextRole === role) return;
    setRoleSwitchDirection(nextRole === "adviser" ? "right" : "left");
    setValue("role", nextRole, { shouldDirty: true, shouldValidate: true });
  }

  function handlePhotoChange(event) {
    const file = event.target.files?.[0];
    setPhotoError("");
    if (!file) return;
    if (!["image/png", "image/jpeg", "image/webp"].includes(file.type)) {
      setPhotoError("Choose a PNG, JPEG, or WebP image.");
      event.target.value = "";
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setPhotoError("Profile photos must be 2 MB or smaller.");
      event.target.value = "";
      return;
    }
    const reader = new FileReader();
    reader.onload = () => setProfilePhoto(String(reader.result || ""));
    reader.onerror = () => setPhotoError("Could not read that image. Please choose another one.");
    reader.readAsDataURL(file);
  }

  async function onSubmit(data) {
    setError("");
    setSuccessMessage("");
    try {
      const res = await registerUser({
        ...data,
        department: data.role === "adviser" ? data.department : null,
        profile_photo: profilePhoto || null,
      });
      setSuccessMessage(res.message);
      setTimeout(() => {
        navigate("/login", { state: { notice: res.message } });
      }, 2000);
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <AuthShell title="Create your account" subtitle="A few details, then your next chapter begins." role={role}>
      {error && <Notice msg={{ type: "error", text: error }} />}
      {successMessage && <Notice msg={{ type: "ok", text: successMessage }} />}
      <div className="register-form-step">
          <div className="register-role-switch-wrap">
            <span className="register-role-switch-label">Register as</span>
            <div className={`register-role-switch register-role-switch--${role}`} role="group" aria-label="Choose account type">
              <span className="register-role-switch-indicator" aria-hidden="true" />
              <button
                type="button"
                aria-pressed={role === "student"}
                onClick={() => switchRole("student")}
                className="register-role-switch-option"
              >
                <GraduationCap className="h-4 w-4" />
                Student
              </button>
              <button
                type="button"
                aria-pressed={role === "adviser"}
                onClick={() => switchRole("adviser")}
                className="register-role-switch-option"
              >
                <BookOpenCheck className="h-4 w-4" />
                Adviser
              </button>
            </div>
          </div>
          <form onSubmit={handleSubmit(onSubmit)} className="grid gap-4 md:grid-cols-2">
            <div className="flex items-center gap-4 md:col-span-2">
              <div className="grid h-16 w-16 flex-none place-items-center overflow-hidden rounded-full border border-border bg-muted/40 text-muted-foreground">
                {profilePhoto ? <img src={profilePhoto} alt="Profile preview" className="h-full w-full object-cover" /> : <UserRound className="h-7 w-7" />}
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <label htmlFor="profile-photo" className="inline-flex h-9 cursor-pointer items-center rounded-full border border-border px-4 text-sm font-semibold text-foreground transition-colors hover:bg-muted">
                    {profilePhoto ? "Change photo" : "Add profile photo"}
                  </label>
                  {profilePhoto && (
                    <button type="button" onClick={() => setProfilePhoto("")} className="inline-flex h-9 items-center gap-1 rounded-full px-3 text-sm text-muted-foreground hover:bg-muted hover:text-foreground">
                      <X className="h-4 w-4" /> Remove
                    </button>
                  )}
                  <input id="profile-photo" type="file" accept="image/png,image/jpeg,image/webp" className="sr-only" onChange={handlePhotoChange} />
                </div>
                <p className="mt-1 text-xs text-muted-foreground">Optional · PNG, JPG, or WebP · max 2 MB</p>
                {photoError && <p className="mt-1 text-xs text-destructive" role="alert">{photoError}</p>}
              </div>
            </div>
            <div key={role} className={`auth-role-panel auth-role-panel--${role} auth-role-panel--from-${roleSwitchDirection} grid gap-4 md:col-span-2 md:grid-cols-2`} aria-live="polite">
              <p className="text-sm text-muted-foreground md:col-span-2">
                {role === "student"
                  ? "Create a student profile to find an adviser and track your research."
                  : "Create an adviser profile. New adviser accounts are reviewed before activation."}
              </p>
              <div className="grid gap-1.5">
                <Label htmlFor="name">Full name</Label>
                <Input id="name" {...register("name")} required minLength={2} autoComplete="name" placeholder="Juan Dela Cruz" aria-invalid={errors.name ? "true" : "false"} />
                {errors.name && <p className="text-sm text-destructive" role="alert">{errors.name.message}</p>}
              </div>
              {role === "student" && (
                <div className="grid gap-1.5">
                  <Label htmlFor="student_group_role">Student group role</Label>
                  <select
                    id="student_group_role"
                    {...register("student_group_role")}
                    className="h-11 w-full rounded-2xl border border-border bg-input px-4 text-sm text-foreground outline-none transition focus:ring-2 focus:ring-ring/30"
                  >
                    <option value="leader">Group leader</option>
                    <option value="member">Group member</option>
                  </select>
                  <p className="text-xs text-muted-foreground">Leaders can invite classmates and review join requests. Members can browse approved groups and request to join.</p>
                </div>
              )}
              {role === "adviser" && (
                <div className="grid gap-1.5">
                  <Label htmlFor="department">Department</Label>
                  <select
                    id="department"
                    {...register("department")}
                    required
                    className="h-11 w-full rounded-2xl border border-border bg-input px-4 text-sm text-foreground outline-none transition focus:ring-2 focus:ring-ring/30"
                    aria-invalid={errors.department ? "true" : "false"}
                  >
                    <option value="">Choose your department</option>
                    {ADVISER_DEPARTMENTS.map((department) => <option key={department} value={department}>{department}</option>)}
                  </select>
                  {errors.department && <p className="text-sm text-destructive" role="alert">{errors.department.message}</p>}
                </div>
              )}
              <div className="grid gap-1.5">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" {...register("email")} required autoComplete="email" placeholder={role === "student" ? "juan@isu.edu.ph" : "maria@isu.edu.ph"} aria-invalid={errors.email ? "true" : "false"} />
                {errors.email && <p className="text-sm text-destructive" role="alert">{errors.email.message}</p>}
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="password">Password</Label>
                <div className="relative">
                  <Input id="password" type={showPassword ? "text" : "password"} className="pr-11" {...register("password")} required minLength={8} autoComplete="new-password" placeholder="••••••••" aria-invalid={errors.password ? "true" : "false"} />
                  <button type="button" onClick={() => setShowPassword((visible) => !visible)} aria-label={showPassword ? "Hide password" : "Show password"} aria-pressed={showPassword} className="absolute inset-y-0 right-0 inline-flex items-center px-3 text-muted-foreground hover:text-foreground">
                    {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
                {errors.password && <p className="text-sm text-destructive" role="alert">{errors.password.message}</p>}
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="confirm">Confirm password</Label>
                <div className="relative">
                  <Input id="confirm" type={showConfirmPassword ? "text" : "password"} className="pr-11" {...register("confirm_password")} required autoComplete="new-password" placeholder="••••••••" aria-invalid={errors.confirm_password ? "true" : "false"} />
                  <button type="button" onClick={() => setShowConfirmPassword((visible) => !visible)} aria-label={showConfirmPassword ? "Hide confirm password" : "Show confirm password"} aria-pressed={showConfirmPassword} className="absolute inset-y-0 right-0 inline-flex items-center px-3 text-muted-foreground hover:text-foreground">
                    {showConfirmPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
                {errors.confirm_password && <p className="text-sm text-destructive" role="alert">{errors.confirm_password.message}</p>}
              </div>
            </div>
            <Button type="submit" disabled={isSubmitting} className="mt-2 md:col-span-2">
              {isSubmitting ? "Creating…" : role === "student" ? "Create student account" : "Register as adviser"}
            </Button>
          </form>
      </div>
    </AuthShell>
  );
}