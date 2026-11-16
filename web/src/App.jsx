import { useEffect, useState } from "react";
import { Navigate, Route, Routes, useOutletContext } from "react-router-dom";
import { clearAuth, getMe, getToken } from "@/api";
import Landing from "@/pages/Landing";
import Register from "@/pages/Register";
import Login from "@/pages/Login";
import VerifyEmail from "@/pages/VerifyEmail";
import Layout from "@/pages/Layout";
import Schedule from "@/pages/Schedule";
import Advisers from "@/pages/Advisers";
import Applications from "@/pages/Applications";
import Groups from "@/pages/Groups";
import Board from "@/pages/Board";
import Settings from "@/pages/Settings";
import Analytics from "@/pages/Analytics";
import Users from "@/pages/Users";
import AdviserApprovals from "@/pages/AdviserApprovals";
import AdminMessages from "@/pages/AdminMessages";
import Notifications from "@/pages/Notifications";
import Milestones from "@/pages/Milestones";
import AuditLog from "@/pages/AuditLog";
import StudentProfileSetup from "@/pages/StudentProfileSetup";

// Kapag hindi pa pwede ang page na ito para sa user (hal. Schedule na wala pang adviser), ibabalik sa tamang home.
function Gate({ page, children }) {
  const ctx = useOutletContext();
  return ctx.allowed.includes(page) ? children : <Navigate to={ctx.home} replace />;
}

function HomeRedirect() {
  const ctx = useOutletContext();
  return <Navigate to={ctx.home} replace />;
}

export default function App() {
  const [user, setUser] = useState(null);
  const [checking, setChecking] = useState(Boolean(getToken()));

  // Pagbukas ng page: kung may token, tanungin ang API kung sino ang naka-login
  useEffect(() => {
    if (!getToken()) return;
    getMe()
      .then(setUser)
      .catch(() => clearAuth())
      .finally(() => setChecking(false));
  }, []);

  const logout = () => {
    clearAuth();
    setUser(null);
  };

  if (checking) return <p className="p-8">Loading…</p>;

  return (
    <>
      <Routes>
        <Route path="/" element={user ? <Navigate to="/home" replace /> : <Landing />} />
        <Route path="/register" element={user ? <Navigate to="/home" replace /> : <Register />} />
        <Route path="/login" element={user ? <Navigate to="/home" replace /> : <Login onLogin={setUser} />} />
        <Route path="/verify-email" element={<VerifyEmail />} />
        <Route
          path="/complete-profile"
          element={user?.role === "student"
            ? (!user.title_setup_required || user.thesis_title?.trim().length >= 10
              ? <Navigate to="/home" replace />
              : <StudentProfileSetup user={user} setUser={setUser} onLogout={logout} />)
            : <Navigate to={user ? "/home" : "/login"} replace />}
        />
        <Route
          element={user
            ? (user.role === "student" && user.title_setup_required && (user.thesis_title || "").trim().length < 10
              ? <Navigate to="/complete-profile" replace />
              : <Layout user={user} setUser={setUser} onLogout={logout} />)
            : <Navigate to="/login" replace />}
        >
          <Route path="/home" element={<HomeRedirect />} />
          <Route path="/schedule" element={<Gate page="schedule"><Schedule /></Gate>} />
          <Route path="/advisers" element={<Gate page="advisers"><Advisers /></Gate>} />
          <Route path="/applications" element={<Gate page="applications"><Applications /></Gate>} />
          <Route path="/groups" element={<Gate page="groups"><Groups /></Gate>} />
          <Route path="/board" element={<Gate page="board"><Board /></Gate>} />
          <Route path="/milestones" element={<Gate page="milestones"><Milestones /></Gate>} />
          <Route path="/notifications" element={<Gate page="notifications"><Notifications /></Gate>} />
          <Route path="/insights" element={<Gate page="insights"><Analytics /></Gate>} />
          <Route path="/analytics" element={<Gate page="analytics"><Analytics /></Gate>} />
          <Route path="/users" element={<Gate page="users"><Users /></Gate>} />
          <Route path="/adviser-approvals" element={<Gate page="adviser-approvals"><AdviserApprovals /></Gate>} />
          <Route path="/messages" element={<Gate page="messages"><AdminMessages /></Gate>} />
          <Route path="/audit-log" element={<Gate page="users"><AuditLog /></Gate>} />
          <Route path="/settings" element={<Gate page="settings"><Settings /></Gate>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  );
}