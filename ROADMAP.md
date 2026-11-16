# Roadmap: Finalizing AdviserLink

List from system review. `[x]` = done, `[ ]` = next.

## Round 1: Security & Trust
- [x] Adviser approval by admin, and deactivate/reactivate account
- [x] Change password in Settings
- [x] Login throttling (5 failed attempts = 10 minute lock)
- [x] No longer using default JWT secret
- [x] CORS and optional email domain restriction in `.env`
- [x] Actual file content validation on upload
- [ ] Forgot password using reset token (requires email/SMTP)
- [ ] Email verification
- [ ] httpOnly cookie instead of localStorage for token

## Round 2: Complete Features
- [ ] Student-Adviser messaging
- [ ] Email/SMS notifications
- [ ] Action items from consultation notes becoming Kanban tasks (notes done)
- [ ] Thesis milestones (Title Defense, Chapters 1-3, Proposal, Final Defense) with deadlines
- [ ] Document versioning and feedback per version
- [ ] Block dates (leave, holiday) in availability
- [ ] Waitlist and alternative adviser suggestions
- [ ] Group support (2-4 members)
- [ ] Admin: reassign adviser, edit capacity, export (CSV/PDF), audit log

## Round 3: UI/UX Polish
- [ ] Loading skeletons and better empty/error states
- [ ] Dark/light toggle and profile photos
- [ ] Better mobile navigation (bottom nav)
- [ ] Accessibility (focus rings, aria labels)
- [ ] Date range filter and export in Analytics
- [x] Model accuracy and plain-language notes in Analytics

## Round 4: Engineering
- [x] Automated tests (pytest) for core logic
- [ ] Split `main.py` into routers and services
- [ ] Alembic migrations instead of auto-alter on startup
- [ ] Pagination for long lists
- [ ] WebSocket/SSE instead of 15-second polling
- [ ] Docker Compose (API, web, MySQL)

## Documentation
- [ ] Update ERD and use case diagram (12 tables)
- [ ] User manual and test plan
- [ ] Deployment guide