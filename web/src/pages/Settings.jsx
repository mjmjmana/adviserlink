import { useEffect, useRef, useState } from "react";
import { Check, Circle, Calendar, Key, Bell as BellIcon, User, GraduationCap, Camera } from "lucide-react";
import { useOutletContext } from "react-router-dom";
import { changePassword, deletePhoto, getProfile, saveProfile, updateMe, uploadPhoto } from "@/api";
import AvailabilityPanel from "@/components/AvailabilityPanel";
import AvailabilityExceptions from "@/components/AvailabilityExceptions";
import { ring, soundOn } from "@/components/Bell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { useTheme } from "@/context/ThemeContext";
import { GlassCard, CardHeader, InfoRow, StatusPill, EmptyState } from "@/components/ui/bento";
import { cn } from "@/lib/utils";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { ADVISER_DEPARTMENTS } from "@/constants/adviserDepartments";

function Step({ done, children }) {
  return (
    <li className="flex items-center gap-2 text-sm">
      {done ? <Check className="h-4 w-4 text-success" /> : <Circle className="h-4 w-4 text-muted-foreground" />}
      <span className={cn(done ? "text-muted-foreground line-through" : "font-semibold")}>{children}</span>
    </li>
  );
}

export default function Settings() {
  const { user, setUser, status, refresh } = useOutletContext();
  const { theme, setTheme } = useTheme();
  const isAdviser = user.role === "adviser";
  const studentGroupRole = user.student_group_role === "member" ? "Group Member" : "Group Leader";
  const [acct, setAcct] = useState({
    name: user.name,
    contact_number: user.contact_number || "",
    research_interests: user.research_interests || "",
    thesis_title: user.thesis_title || "",
  });
  const [prof, setProf] = useState({ department: "", specialization_tags_text: "", certifications: "", max_capacity: 10 });
  const [sound, setSound] = useState(soundOn());
  const [msg, setMsg] = useState({ type: "", text: "" });
  const [pw, setPw] = useState({ current_password: "", new_password: "", confirm_password: "" });
  const [stagedPhoto, setStagedPhoto] = useState(null);
  const [photoUploading, setPhotoUploading] = useState(false);
  const [profileDialogOpen, setProfileDialogOpen] = useState(false);
  const photoInputRef = useRef(null);

  useEffect(() => {
    if (isAdviser) getProfile().then((p) => setProf({
      department: p.department || "",
      specialization_tags_text: p.specialization_tags_text,
      certifications: p.certifications,
      max_capacity: p.max_capacity,
    })).catch((error) => setMsg({ type: "error", text: error.message }));
  }, [isAdviser]);

  async function saveAccount(e) {
    e.preventDefault();
    try { setUser(await updateMe(acct)); setMsg({ type: "ok", text: "Account saved." }); } catch (err) { setMsg({ type: "error", text: err.message }); }
  }
  async function saveAdviser(e) {
    e.preventDefault();
    try {
      await saveProfile({ department: prof.department, specialization_tags: prof.specialization_tags_text, certifications: prof.certifications, max_capacity: Number(prof.max_capacity) });
      setMsg({ type: "ok", text: "Adviser profile saved. Students can now find you by these keywords." });
      refresh();
    } catch (err) { setMsg({ type: "error", text: err.message }); }
  }
  async function savePassword(e) {
    e.preventDefault();
    if (pw.new_password !== pw.confirm_password) { setMsg({ type: "error", text: "The two new passwords do not match." }); return; }
    try {
      await changePassword(pw);
      setPw({ current_password: "", new_password: "", confirm_password: "" });
      setMsg({ type: "ok", text: "Password changed." });
    } catch (err) { setMsg({ type: "error", text: err.message }); }
  }
  function toggleSound(on) {
    setSound(on);
    localStorage.setItem("adviserlink_sound", on ? "on" : "off");
    if (on) ring();
  }

  async function handlePhotoChange(e) {
    const file = e.target.files[0];
    e.target.value = "";
    if (!file) return;
    if (!["image/png", "image/jpeg", "image/webp"].includes(file.type)) {
      setMsg({ type: "error", text: "Please choose a PNG, JPEG, or WebP image." });
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      setMsg({ type: "error", text: "Image too large (max 2MB)." });
      return;
    }
    const reader = new FileReader();
    reader.onload = (event) => {
      if (typeof event.target.result !== "string") {
        setMsg({ type: "error", text: "Could not preview this image. Please try another file." });
        return;
      }
      setStagedPhoto(event.target.result);
    };
    reader.onerror = () => setMsg({ type: "error", text: "Could not read this image. Please try again." });
    reader.readAsDataURL(file);
  }

  async function confirmPhoto() {
    if (!stagedPhoto) return;
    setPhotoUploading(true);
    try {
      const res = await uploadPhoto(stagedPhoto);
      setUser((current) => ({ ...current, profile_photo: res.photo_url }));
      setStagedPhoto(null);
      setMsg({ type: "ok", text: "Profile photo updated." });
    } catch (err) {
      setMsg({ type: "error", text: err.message });
    } finally {
      setPhotoUploading(false);
    }
  }

  async function removePhoto() {
    setPhotoUploading(true);
    try {
      await deletePhoto();
      setUser((current) => ({ ...current, profile_photo: null }));
      setStagedPhoto(null);
      setMsg({ type: "ok", text: "Profile photo removed." });
    } catch (err) {
      setMsg({ type: "error", text: err.message });
    } finally {
      setPhotoUploading(false);
    }
  }

  return (
    <>
      <div className="grid gap-1">
        <h1 className="text-3xl font-extrabold tracking-tight">Your settings</h1>
        <p className="text-foreground/70">View or edit your account.</p>
      </div>
      {isAdviser && !(status.profile_ready && status.has_availability) && (
        <GlassCard className="p-5">
          <b>Finish setting up so students can find and book you</b>
          <ul className="mt-2 grid gap-1.5">
            <Step done={status.profile_ready}>Add your specializations (keywords students search for)</Step>
            <Step done={status.has_availability}>Add your open times</Step>
          </ul>
        </GlassCard>
      )}
      <Notice msg={msg} />
      <Dialog open={profileDialogOpen} onOpenChange={setProfileDialogOpen}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle>Your profile</DialogTitle>
            <DialogDescription>View your account details or choose a profile photo.</DialogDescription>
          </DialogHeader>
          <div className="grid justify-items-center gap-4 py-2 text-center">
            {stagedPhoto || user.profile_photo ? (
              <img src={stagedPhoto || user.profile_photo} alt={`${acct.name}'s profile`} className="h-28 w-28 rounded-full border-2 border-primary object-cover" />
            ) : (
              <div className="flex h-28 w-28 items-center justify-center rounded-full bg-primary/20 text-4xl font-bold text-primary">
                {acct.name.charAt(0).toUpperCase()}
              </div>
            )}
            <div className="grid gap-1">
              <p className="text-lg font-bold">{acct.name}</p>
              <p className="text-sm text-muted-foreground">{user.email}</p>
              <p className="text-sm capitalize text-muted-foreground">
                {user.role === "student" ? `Student · ${studentGroupRole}` : user.role}
              </p>
              {acct.contact_number && <p className="text-sm text-muted-foreground">{acct.contact_number}</p>}
            </div>
            <input
              ref={photoInputRef}
              type="file"
              accept="image/png,image/jpeg,image/webp"
              onChange={handlePhotoChange}
              className="sr-only"
              disabled={photoUploading}
            />
            {stagedPhoto ? (
              <div className="flex flex-wrap justify-center gap-2">
                <Button type="button" variant="outline" onClick={() => setStagedPhoto(null)} disabled={photoUploading}>Cancel</Button>
                <Button type="button" onClick={confirmPhoto} disabled={photoUploading}>
                  {photoUploading ? "Saving photo..." : "Confirm photo"}
                </Button>
              </div>
            ) : (
              <div className="flex flex-wrap justify-center gap-2">
                <Button type="button" onClick={() => photoInputRef.current?.click()} disabled={photoUploading}>
                  <Camera className="mr-2 h-4 w-4" />
                  {user.profile_photo ? "Change photo" : "Choose profile photo"}
                </Button>
                {user.profile_photo && (
                  <Button type="button" variant="outline" onClick={removePhoto} disabled={photoUploading}>
                    Remove photo
                  </Button>
                )}
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>
      <div className="grid items-stretch gap-5 md:grid-cols-2">
        {/* Account & Profile */}
        <GlassCard className="md:col-span-2">
          <CardHeader
            icon={<User className="h-5 w-5" />}
            title="Account"
            description="Your personal information and preferences."
            iconColor="primary"
            actions={
              <div className="flex items-center gap-2">
                <span className="text-sm text-muted-foreground">Theme</span>
                <select
                  value={theme}
                  onChange={(e) => setTheme(e.target.value)}
                  className="rounded-md border border-input bg-background px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  <option value="system">System</option>
                  <option value="light">Light</option>
                  <option value="dark">Dark</option>
                </select>
              </div>
            }
          />
          <div className="grid gap-5 p-4 pt-0 sm:grid-cols-[5rem_minmax(0,1fr)] sm:items-start sm:gap-6">
            <div className="relative">
              <button
                type="button"
                onClick={() => setProfileDialogOpen(true)}
                className="group relative rounded-full focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
                aria-label="View profile and choose profile photo"
              >
                {user.profile_photo ? (
                  <img src={user.profile_photo} alt="Profile" className="h-20 w-20 rounded-full border-2 border-primary object-cover" />
                ) : (
                  <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary/20">
                    <span className="text-2xl font-bold text-primary">{user.name.charAt(0).toUpperCase()}</span>
                  </div>
                )}
                <span className="absolute bottom-0 right-0 flex h-8 w-8 items-center justify-center rounded-full bg-muted text-foreground transition-colors group-hover:bg-muted/80">
                  {photoUploading ? (
                    <span className="h-4 w-4 animate-spin rounded-full border-2 border-primary border-t-transparent" />
                  ) : (
                    <Camera className="h-4 w-4" />
                  )}
                </span>
              </button>
            </div>
            <div className="grid min-w-0 gap-4">
              <div className="grid gap-1.5">
                <Label htmlFor="name">Full name</Label>
                <Input id="name" value={acct.name} onChange={(e) => setAcct({ ...acct, name: e.target.value })} required minLength={2} />
              </div>
              <div className="grid gap-1.5 sm:grid-cols-2 sm:gap-4">
                <div className="grid gap-1.5">
                  <Label htmlFor="email">Email</Label>
                  <Input id="email" value={user.email} disabled />
                </div>
                <div className="grid gap-1.5">
                  <Label htmlFor="contact">Contact number</Label>
                  <Input id="contact" value={acct.contact_number} onChange={(e) => setAcct({ ...acct, contact_number: e.target.value })} maxLength={20} />
                </div>
              </div>
              {user.role === "student" && (
                <div className="grid gap-1.5">
                  <Label>Student account type</Label>
                  <div className="flex min-h-11 items-center gap-2 rounded-xl border border-border/50 bg-muted/30 px-3">
                    <StatusPill tone="student" showDot>{studentGroupRole}</StatusPill>
                    <span className="text-xs text-muted-foreground">Set when the account was created</span>
                  </div>
                </div>
              )}
              {user.role === "student" && (
                <>
                  <div className="grid gap-1.5">
                    <Label htmlFor="thesis-title">Complete thesis / capstone title</Label>
                    <textarea
                      id="thesis-title"
                      value={acct.thesis_title}
                      onChange={(e) => setAcct({ ...acct, thesis_title: e.target.value })}
                      placeholder="Enter your complete working title"
                      minLength={10}
                      maxLength={500}
                      required
                      className="min-h-24 rounded-xl border border-input bg-background px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    />
                  </div>
                  <div className="grid gap-1.5">
                    <Label htmlFor="research-interests">Research interests (optional)</Label>
                    <Input
                      id="research-interests"
                      value={acct.research_interests}
                      onChange={(e) => setAcct({ ...acct, research_interests: e.target.value })}
                      placeholder="e.g. sustainable agriculture, machine learning"
                      maxLength={500}
                    />
                    <p className="text-xs text-muted-foreground">These keywords can help match your project with other students.</p>
                  </div>
                </>
              )}
              <div className="border-t border-border/30 pt-4">
                <Button onClick={saveAccount}>Save account</Button>
              </div>
            </div>
          </div>
        </GlassCard>

        {/* Adviser Profile or Student Notifications */}
        {isAdviser ? (
          <GlassCard className="md:col-span-2">
            <CardHeader
              icon={<GraduationCap className="h-5 w-5" />}
              title="Adviser profile"
              description="Students search using these keywords."
              iconColor="primary"
            />
            <form onSubmit={saveAdviser} className="p-4 pt-0 grid gap-4">
              <div className="grid gap-1.5">
                <Label htmlFor="adviser-department">Department</Label>
                <select
                  id="adviser-department"
                  value={prof.department}
                  onChange={(e) => setProf({ ...prof, department: e.target.value })}
                  required
                  className="h-11 w-full rounded-2xl border border-border bg-input px-4 text-sm text-foreground outline-none transition focus:ring-2 focus:ring-ring/30"
                >
                  <option value="">Choose your department</option>
                  {ADVISER_DEPARTMENTS.map((department) => <option key={department} value={department}>{department}</option>)}
                </select>
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="tags">Specializations (comma-separated)</Label>
                <Input id="tags" value={prof.specialization_tags_text} onChange={(e) => setProf({ ...prof, specialization_tags_text: e.target.value })} placeholder="web development, databases, IoT" maxLength={500} />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="certs">Certifications</Label>
                <Input id="certs" value={prof.certifications} onChange={(e) => setProf({ ...prof, certifications: e.target.value })} maxLength={500} />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="cap">Max advisees</Label>
                <Input id="cap" type="number" min="1" max="50" value={prof.max_capacity} onChange={(e) => setProf({ ...prof, max_capacity: e.target.value })} required />
              </div>
              <Button type="submit">Save profile</Button>
            </form>
          </GlassCard>
        ) : (
          <GlassCard>
            <CardHeader
              icon={<BellIcon className="h-5 w-5" />}
              title="Notifications"
              description={user.role === "admin"
                ? "Alerts for adviser approval requests."
                : "Pop-ups and a short ring when something new arrives."}
              iconColor="primary"
            />
            <div className="p-4 pt-0 grid content-start gap-3">
              <label className="flex items-center gap-2 text-sm font-semibold">
                <input type="checkbox" className="h-4 w-4 accent-[hsl(var(--primary))]" checked={sound} onChange={(e) => toggleSound(e.target.checked)} />
                {user.role === "admin" ? "Play sound for new alerts" : "Ring when a new notification arrives"}
              </label>
              <p className="text-sm text-muted-foreground">
                {user.role === "admin"
                  ? "Requests appear in Notifications and Adviser approvals while AdviserLink is open."
                  : "You also get a reminder 15 minutes before a consultation while AdviserLink is open."}
              </p>
            </div>
          </GlassCard>
        )}

        {/* Adviser Availability */}
        {isAdviser && (
          <GlassCard className="md:col-span-2">
            <Tabs defaultValue="availability" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="availability"><span className="flex items-center gap-1"><Calendar className="h-4 w-4" /> Availability</span></TabsTrigger>
                <TabsTrigger value="exceptions"><span className="flex items-center gap-1"><Calendar className="h-4 w-4" /> Exceptions</span></TabsTrigger>
              </TabsList>
              <TabsContent value="availability" className="pt-4">
                <AvailabilityPanel onChange={refresh} />
              </TabsContent>
              <TabsContent value="exceptions" className="pt-4">
                <AvailabilityExceptions onChange={refresh} />
              </TabsContent>
            </Tabs>
          </GlassCard>
        )}

        {/* Adviser Notifications */}
        {isAdviser && (
          <GlassCard>
            <CardHeader
              icon={<BellIcon className="h-5 w-5" />}
              title="Notifications"
              description="Pop-ups and a short ring when something new arrives."
              iconColor="primary"
            />
            <div className="p-4 pt-0 grid content-start gap-3">
              <label className="flex items-center gap-2 text-sm font-semibold">
                <input type="checkbox" className="h-4 w-4 accent-[hsl(var(--primary))]" checked={sound} onChange={(e) => toggleSound(e.target.checked)} />
                Ring when a new notification arrives
              </label>
              <p className="text-sm text-muted-foreground">You also get a reminder 15 minutes before a consultation while AdviserLink is open.</p>
            </div>
          </GlassCard>
        )}

        {/* Change Password */}
        <GlassCard className="md:col-span-2">
          <CardHeader
            icon={<Key className="h-5 w-5" />}
            title="Change password"
            description="Use at least 8 characters."
            iconColor="primary"
          />
          <form onSubmit={savePassword} className="p-4 pt-0 grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="cur">Current password</Label>
              <Input id="cur" type="password" value={pw.current_password} onChange={(e) => setPw({ ...pw, current_password: e.target.value })} required autoComplete="current-password" />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="new">New password</Label>
              <Input id="new" type="password" value={pw.new_password} onChange={(e) => setPw({ ...pw, new_password: e.target.value })} required minLength={8} autoComplete="new-password" />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="conf">Confirm new password</Label>
              <Input id="conf" type="password" value={pw.confirm_password} onChange={(e) => setPw({ ...pw, confirm_password: e.target.value })} required autoComplete="new-password" />
            </div>
            <Button type="submit">Change password</Button>
          </form>
        </GlassCard>
      </div>
    </>
  );
}