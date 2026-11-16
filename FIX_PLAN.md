# AdviserLink Complete Fix Plan

## Issues Identified

### 1. Theme System Broken (Critical)
- `ThemeToggle` in `Layout.jsx` has `onChange={(t) => {}}` - does nothing!
- Theme only applied in `Settings.jsx` but not globally on app load
- No theme persistence across page refreshes
- Mobile app only has dark theme hardcoded

### 2. Analytics Tab Names Need Changing
- "Descriptive" → "What Happened (Summary)"
- "Diagnostic" → "Why It Happened (Diagnosis)"
- "Predictive" → "What Will Happen (Forecast)"
- "Prescriptive" → "What To Do (Actions)"

### 3. UI/UX Issues
- Text placement and font colors need fixing
- Contrast issues in light/dark modes
- Inconsistent spacing and layout

### 4. Database Requirements (Verify All Working)
- ✅ Normalization
- ✅ Triggers (in db_setup.py)
- ✅ Transactions (in main.py)
- ✅ Login History (login_history table)
- ✅ Audit Logs (audit_logs table)
- ✅ Referential Integrity (FK constraints)
- ✅ Optimization (indexes, partitioning in db_setup.py)
- ✅ Encryption (encrypted_contact, encryption_iv columns)
- ✅ Domain Constraints (CHECK constraints)
- ❌ Limit Database User Privilege - NEED TO ADD
- ❌ Recovery and Backup - NEED TO ADD demonstration/plan

### 5. Code Comments
- Mixed Tagalog/English → All English, concise statements

### 6. Seed Data
- Plain text passwords → Replace with bcrypt hashes

### 7. Mobile Theme Support
- Add theme switching to Flutter app

### 8. Image References
- 3 images in adviserlink folder for design reference

---

## Implementation Order

1. **Create Theme Context/Provider** (React) - Global theme management
2. **Fix Layout.jsx** - Connect ThemeToggle to global theme
3. **Fix Settings.jsx** - Use global theme context
4. **Update Analytics.jsx** - Change tab names
5. **Update index.css** - Fix contrast, text colors, spacing
6. **Update Mobile theme.dart** - Add light theme and switching
7. **Update Mobile main.dart** - Use theme from storage
8. **Fix Database** - Add user privileges, backup procedures
9. **Update Seed Data** - Proper bcrypt passwords
10. **Convert Comments** - Tagalog → English
11. **Verify All Features Work** - End-to-end testing