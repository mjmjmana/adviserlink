import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { updateMe } from "@/api";
import Logo from "@/components/Logo";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Notice } from "@/components/ui/alert";
import { GlassCard, PersonChip } from "@/components/ui/bento";
import { ArrowLeft, BookOpenCheck, Check, GraduationCap, Sparkles, Target } from "lucide-react";

function ProfileSetupShowcase() {
  return (
    <aside className="auth-showcase auth-showcase--student" aria-label="Complete your research profile">
      <div className="auth-showcase-copy">
        <span className="auth-showcase-eyebrow"><Sparkles size={14} /> YOUR STUDENT SPACE</span>
        <h2>Start with your research idea.</h2>
        <p>Your title helps connect you with students and advisers who understand what you want to build.</p>
      </div>
      <div className="auth-world">
        <img
          className="auth-team-image"
          src={`${import.meta.env.BASE_URL}adviserlink-research-team.png`}
          alt="Students and advisers collaborating on a research project"
        />
        <div className="auth-floating-card auth-floating-card--match">
          <span className="auth-floating-icon"><GraduationCap size={17} /></span>
          <span><b>Find your people</b><small>Research starts together</small></span>
          <span className="auth-match-status"><Check size={12} /></span>
        </div>
        <div className="auth-world-caption">
          <span className="auth-caption-mark"><BookOpenCheck size={15} /></span>
          <span><small>ADVISERLINK WORKSPACE</small><b>Every next step, connected.</b></span>
          <span className="auth-caption-spark"><Sparkles size={15} /></span>
        </div>
      </div>
      <div className="auth-journey-card">
        <div className="auth-journey-heading">
          <span className="auth-journey-icon"><Target size={16} /></span>
          <span><small>ONE STEP AT A TIME</small><b>Your research journey</b></span>
          <span className="auth-journey-avatars" aria-hidden="true"><i>S</i><i>A</i></span>
        </div>
        <div className="auth-journey-steps">
          <div className="auth-journey-step"><span className="is-complete"><Check size={11} /></span><b>Add your title</b></div>
          <div className="auth-journey-step"><span>02</span><b>Find your group</b></div>
          <div className="auth-journey-step"><span>03</span><b>Make progress</b></div>
        </div>
      </div>
      <div className="auth-showcase-bottom">
        <span>Made for students and advisers.</span>
        <span className="auth-showcase-dots"><i /><i /><i /></span>
      </div>
    </aside>
  );
}

export default function StudentProfileSetup({ user, setUser, onLogout }) {
  const navigate = useNavigate();
  const [title, setTitle] = useState(user.thesis_title || "");
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });

  async function saveProfile(event) {
    event.preventDefault();
    setSaving(true);
    setMsg({ type: "", text: "" });
    try {
      const updated = await updateMe({
        name: user.name,
        contact_number: user.contact_number || "",
        thesis_title: title.trim(),
      });
      setUser(updated);
      navigate("/home", { replace: true });
    } catch (error) {
      setMsg({ type: "error", text: error.message });
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="auth-shell auth-shell--login relative flex min-h-screen flex-col">
      <header className="auth-header mx-auto flex w-full max-w-6xl items-center justify-between px-4 py-4">
        <Link to="/login" onClick={onLogout} className="auth-back-link inline-flex items-center gap-2 text-sm font-semibold transition-colors">
          <ArrowLeft className="h-4 w-4" /> Log out
        </Link>
        <Logo size={36} withName />
      </header>
      <main className="auth-main mx-auto grid w-full max-w-6xl flex-1 items-stretch gap-5 px-4 pb-5 pt-1 lg:grid-cols-[minmax(0,1.08fr)_minmax(420px,.92fr)]">
        <ProfileSetupShowcase />
        <GlassCard variant="default" padding="none" className="auth-form-card">
          <div className="auth-form-inner justify-center">
            <div className="auth-form-heading">
              <span className="auth-form-overline">COMPLETE YOUR STUDENT PROFILE</span>
              <h1>What is your thesis or capstone title?</h1>
              <p>Add your complete working title before using group search or adviser features. You can update it later in Settings.</p>
            </div>
            {msg.text && <Notice msg={msg} />}
            <div className="auth-form-content">
              <form onSubmit={saveProfile} className="grid gap-3">
                <Label htmlFor="thesis-title">Complete thesis / capstone title</Label>
                <Input
                  id="thesis-title"
                  value={title}
                  onChange={(event) => setTitle(event.target.value)}
                  placeholder="Enter your complete working title"
                  minLength={10}
                  maxLength={500}
                  required
                  autoFocus
                />
                <p className="text-xs text-muted-foreground">
                  This title helps match your project with student members and advisers.
                </p>
                <Button type="submit" className="mt-2" disabled={saving || title.trim().length < 10}>
                  {saving ? "Saving profile…" : "Save title and continue"}
                </Button>
              </form>
            </div>
            <p className="auth-form-footer">AdviserLink <span>·</span> ISU Echague</p>
          </div>
        </GlassCard>
      </main>
    </div>
  );
}
