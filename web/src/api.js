// Lahat ng pakikipag-usap sa Python API ay dumadaan dito.
const TOKEN_KEY = "adviserlink_token";
const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || "").replace(/\/+$/, "");

export const getToken = () => localStorage.getItem(TOKEN_KEY);
export const saveToken = (t) => localStorage.setItem(TOKEN_KEY, t);
export const clearToken = () => localStorage.removeItem(TOKEN_KEY);

// Call this on logout to clear everything
export const clearAuth = () => {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem("adviserlink_sound");
  localStorage.removeItem("adviserlink_theme");
};

// Ginagawang maikli at malinaw na mensahe ang error ng FastAPI
function readError(data) {
  const d = data && data.detail;
  if (typeof d === "string") return d;
  if (Array.isArray(d) && d.length > 0) {
    const e = d[0];
    const field = e.loc ? e.loc[e.loc.length - 1] : "";
    if (field === "password" && e.type === "string_too_short") return "Your password needs at least 8 characters.";
    if (field === "email") return "Enter a valid email address.";
    if (field === "name") return "Enter your full name (at least 2 characters).";
    if (field === "topic_brief") return "Describe your topic in at least 10 characters.";
    return String(e.msg).replace(/^Value error, /, "");
  }
  return "Something went wrong. Please try again.";
}

async function send(path, { method = "GET", body, form, auth = true } = {}) {
  const headers = {};
  if (!form) headers["Content-Type"] = "application/json";
  if (auth && getToken()) headers.Authorization = `Bearer ${getToken()}`;
  let res;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, { method, headers, body: form || (body ? JSON.stringify(body) : undefined) });
  } catch {
    throw new Error("Cannot reach the server. Is the Python API running on port 8001?");
  }
  return res;
}

async function request(path, opts = {}) {
  const res = await send(path, opts);
  const data = await res.json().catch(() => ({}));
  if (res.status === 401 && opts.auth !== false) {
    clearAuth();
    if (typeof window !== "undefined") window.location.href = `${import.meta.env.BASE_URL}login`;
    throw new Error("Session expired. Please log in again.");
  }
  if (!res.ok) throw new Error(readError(data));
  return data;
}

const qs = (o) => new URLSearchParams(o).toString();

// ---- auth
export const registerUser = (form) => request("/api/register", { method: "POST", body: form, auth: false });
export const loginUser = (form) => request("/api/login", { method: "POST", body: form, auth: false });
export const getMe = () => request("/api/me");
export const getStatus = () => request("/api/status");
export const changePassword = (body) => request("/api/me/password", { method: "POST", body });
export const setUserStatus = (id, status) => request(`/api/admin/users/${id}/status`, { method: "PATCH", body: { status } });
export const updateMe = (body) => request("/api/me", { method: "PUT", body });
export const uploadPhoto = (imageData) => request("/api/me/photo", { method: "POST", body: { image: imageData } });
export const deletePhoto = () => request("/api/me/photo", { method: "DELETE" });

// ---- email verification
export const verifyEmail = (token) => request("/api/auth/verify-email", { method: "POST", body: { token }, auth: false });
export const resendVerification = (email) => request("/api/auth/resend-verification", { method: "POST", body: { email }, auth: false });
export const getDevToken = (email, purpose = "verify-email") => request(`/api/auth/dev-token?${qs({ email, purpose })}`, { auth: false });

// ---- advisers
export const listAdvisers = (q = "") => request(`/api/advisers?${qs({ q })}`);
export const getProfile = () => request("/api/adviser/profile");
export const saveProfile = (body) => request("/api/adviser/profile", { method: "PUT", body });
export const getAvailability = () => request("/api/availability");
export const addAvailability = (body) => request("/api/availability", { method: "POST", body });
export const updateAvailability = (id, body) => request(`/api/availability/${id}`, { method: "PUT", body });
export const delAvailability = (id) => request(`/api/availability/${id}`, { method: "DELETE" });
export const getSlots = (id, start, end) => request(`/api/advisers/${id}/slots?${qs({ start, end })}`);

// ---- applications
export const applyTo = (body) => request("/api/applications", { method: "POST", body });
export const myApplications = () => request("/api/applications");
export const decideApplication = (id, status) => request(`/api/applications/${id}`, { method: "PATCH", body: { status } });
export const withdrawApplication = (id) => request(`/api/applications/${id}`, { method: "DELETE" });

// ---- bookings
export const createBooking = (body) => request("/api/bookings", { method: "POST", body });
export const setMeeting = (id, body) => request(`/api/bookings/${id}/meeting`, { method: "PATCH", body });
export const acceptMeetingDetails = (id) => request(`/api/bookings/${id}/accept-meeting`, { method: "POST" });
export const myBookings = (start, end) => request(`/api/bookings?${qs({ start, end })}`);
export const cancelBooking = (id, reason) => request(`/api/bookings/${id}/cancel`, { method: "POST", body: { reason } });
export const completeBooking = (id, body) => request(`/api/bookings/${id}/complete`, { method: "POST", body });

// ---- board
export const getBoard = (appId) => request(`/api/applications/${appId}/board`);
export const addTask = (appId, body) => request(`/api/applications/${appId}/tasks`, { method: "POST", body });
export const patchTask = (id, body) => request(`/api/tasks/${id}`, { method: "PATCH", body });
export const deleteTask = (id) => request(`/api/tasks/${id}`, { method: "DELETE" });
export const addComment = (id, body, file = null) => {
  const form = new FormData();
  form.append("body", body);
  if (file) form.append("file", file);
  return request(`/api/tasks/${id}/comments`, { method: "POST", form });
};

// ---- documents
export const listDocs = (appId) => request(`/api/applications/${appId}/documents`);
export const uploadDoc = (appId, file, category, taskId = null) => {
  const form = new FormData();
  form.append("file", file);
  form.append("category", category);
  if (taskId) form.append("task_id", taskId);
  return request(`/api/applications/${appId}/documents`, { method: "POST", form });
};
export const deleteDoc = (id) => request(`/api/documents/${id}`, { method: "DELETE" });
export async function previewDoc(id) {
  const res = await send(`/api/documents/${id}/download?preview=true`);
  if (!res.ok) throw new Error("Could not preview the file.");
  return res.blob();
}
export async function downloadDoc(id, filename) {
  const res = await send(`/api/documents/${id}/download`);
  if (!res.ok) throw new Error("Could not download the file.");
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

// ---- notifications
export const getNotifications = (limit = 30) => request(`/api/notifications?${qs({ limit })}`);
export const readNotification = (id) => request(`/api/notifications/${id}/read`, { method: "POST" });

// ---- analytics at admin
export const getAnalytics = () => request("/api/analytics");
export const getAnalyticsDetails = (category) => request(`/api/analytics/details/${encodeURIComponent(category)}`);
export const adminUsers = (q = "", role = "", status = "", limit = 50, offset = 0) => request(`/api/admin/users?${qs({ q, role, status, limit, offset })}`);
export const readAllNotifications = () => request("/api/notifications/read-all", { method: "POST" });

// ---- Sprint 3: matalinong features
export const getAttention = () => request("/api/attention");
export const getNextSlots = (adviserId, limit = 6) => request(`/api/advisers/${adviserId}/next-slots?${qs({ limit })}`);
export const rescheduleBooking = (id, body) => request(`/api/bookings/${id}/reschedule`, { method: "POST", body });
export const rateBooking = (id, body) => request(`/api/bookings/${id}/rating`, { method: "POST", body });
export const nudgeAdvisee = (applicationId) => request(`/api/applications/${applicationId}/nudge`, { method: "POST" });
export async function downloadIcs(id) {
  const res = await send(`/api/bookings/${id}/calendar.ics`);
  if (!res.ok) throw new Error("Could not download the calendar file.");
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement("a");
  a.href = url;
  a.download = "consultation.ics";
  a.click();
  URL.revokeObjectURL(url);
}

// ---- Phase B: New features
// ---- Messages
export const getMessages = (appId, limit = 50, targetMessageId = null) => request(`/api/applications/${appId}/messages?${qs({ limit, ...(targetMessageId ? { target_message_id: targetMessageId } : {}) })}`);
export const sendMessage = (appId, body) => request(`/api/applications/${appId}/messages`, { method: "POST", body: { body } });
export const markMessagesRead = (appId, throughMessageId) => request(`/api/applications/${appId}/messages/read?${qs({ through_message_id: throughMessageId })}`, { method: "POST" });
export const updateChatActivity = (appId, typing = false) => request(`/api/applications/${appId}/messages/activity`, { method: "POST", body: { typing } });
export const getChatActivity = (appId) => request(`/api/applications/${appId}/messages/activity`);
export const getAdminMessageThreads = () => request("/api/admin/messages");
export const getAdminMessages = (appId, limit = 100, targetMessageId = null) => request(`/api/admin/messages/${appId}?${qs({ limit, ...(targetMessageId ? { target_message_id: targetMessageId } : {}) })}`);
export const sendAdminMessage = (appId, body) => request(`/api/admin/messages/${appId}`, { method: "POST", body: { body } });

// ---- Milestones
export const getMilestones = (appId) => request(`/api/applications/${appId}/milestones`);
export const createMilestone = (appId, body) => request(`/api/applications/${appId}/milestones`, { method: "POST", body });
export const updateMilestone = (id, body) => request(`/api/milestones/${id}`, { method: "PATCH", body });
export const deleteMilestone = (id) => request(`/api/milestones/${id}`, { method: "DELETE" });

// ---- Document Versions
export const getDocumentVersions = (docId) => request(`/api/documents/${docId}/versions`);
export const uploadDocumentVersion = (docId, file, comment) => {
  const form = new FormData();
  form.append("file", file);
  if (comment) form.append("comment", comment);
  return request(`/api/documents/${docId}/versions`, { method: "POST", form });
};
export const downloadDocumentVersion = async (versionId, filename) => {
  const res = await send(`/api/document-versions/${versionId}/download`);
  if (!res.ok) throw new Error("Could not download the file.");
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
};

// ---- Availability Exceptions
export const getAvailabilityExceptions = () => request("/api/adviser/exceptions");
export const addAvailabilityException = (body) => request("/api/adviser/exceptions", { method: "POST", body });
export const deleteAvailabilityException = (id) => request(`/api/adviser/exceptions/${id}`, { method: "DELETE" });

// ---- Waitlist
export const joinWaitlist = (body) => request("/api/waitlist", { method: "POST", body });
export const myWaitlist = () => request("/api/waitlist/me");
export const adviserWaitlist = () => request("/api/adviser/waitlist");
export const notifyWaitlist = (id) => request(`/api/waitlist/${id}/notify`, { method: "POST" });
export const cancelWaitlist = (id) => request(`/api/waitlist/${id}/cancel`, { method: "POST" });

// ---- Group Applications
export const inviteGroupMember = (appId, body) => request(`/api/applications/${appId}/group-invitations`, { method: "POST", body });
export const getGroupMembers = (appId) => request(`/api/applications/${appId}/group`);
export const getGroupInvitations = (appId) => request(`/api/applications/${appId}/group-invitations`);
export const removeGroupMember = (id) => request(`/api/group/${id}`, { method: "DELETE" });
export const myGroupInvitations = () => request("/api/group-invitations");
export const acceptGroupInvitation = (id) => request(`/api/group-invitations/${id}/accept`, { method: "POST" });
export const declineGroupInvitation = (id) => request(`/api/group-invitations/${id}/decline`, { method: "POST" });
export const cancelGroupInvitation = (id) => request(`/api/group-invitations/${id}`, { method: "DELETE" });
export const getAvailableGroups = (query) => request(`/api/groups?${qs({ q: query })}`);
export const getAvailableGroupMembers = (topic) => request(`/api/group-members?${qs({ q: topic })}`);
export const createStudentGroupRequest = (userId) => request("/api/student-group-requests", { method: "POST", body: { user_id: userId } });
export const myStudentGroupRequests = () => request("/api/student-group-requests");
export const decideStudentGroupRequest = (id, status) => request(`/api/student-group-requests/${id}`, { method: "PATCH", body: { status } });
export const requestGroupJoin = (appId) => request(`/api/applications/${appId}/group-join-requests`, { method: "POST" });
export const getGroupJoinRequests = (appId) => request(`/api/applications/${appId}/group-join-requests`);
export const decideGroupJoinRequest = (id, status) => request(`/api/group-join-requests/${id}`, { method: "PATCH", body: { status } });

// ---- Admin Audit Log
export const getAdminAuditLog = (limit = 100) => request(`/api/admin/audit-log?${qs({ limit })}`);

// ---- Admin Export
async function exportFile(path) {
  const res = await send(path, { method: "GET" });
  if (res.status === 401) {
    clearAuth();
    if (typeof window !== "undefined") window.location.href = `${import.meta.env.BASE_URL}login`;
    throw new Error("Session expired. Please log in again.");
  }
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    throw new Error(readError(data));
  }
  return res;
}

export const exportUsersCSV = () => exportFile("/api/admin/export/users");
export const exportApplicationsCSV = () => exportFile("/api/admin/export/applications");
export const exportBookingsCSV = () => exportFile("/api/admin/export/bookings");
export const exportAnalyticsReport = () => exportFile("/api/admin/export/analytics");
