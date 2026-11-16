# AdviserLink deployment checklist

This guide prepares the application for a controlled deployment. It does not
provision a cloud account, database, domain, TLS certificate, or SMTP service.
Keep credentials in the host's secret manager or protected environment, never
in Git, browser code, logs, or this guide.

## 1. Production configuration

Set these backend environment variables (or protected `backend/.env` file):

```ini
APP_ENV=production
RUN_SCHEMA_MIGRATIONS=false
DATABASE_URL=mysql+pymysql://adviserlink_app:<url-encoded-password>@<private-db-host>:3306/adviserlink_db
JWT_SECRET=<at-least-32-random-characters>
JWT_HOURS=8
APP_BASE_URL=https://adviserlink.example.edu
CORS_ORIGINS=https://adviserlink.example.edu
SKIP_EMAIL_VERIFICATION=false
SMTP_HOST=<smtp-host>
SMTP_PORT=587
SMTP_USER=<smtp-user>
SMTP_PASS=<smtp-secret>
SMTP_FROM=<verified-sender-address>
UPLOAD_DIR=<persistent-private-storage-path>
```

Production startup rejects a missing/placeholder JWT secret, non-HTTPS app
URL/origin, wildcard CORS, missing SMTP configuration, development email
verification, the MySQL root account, or an unset persistent upload location.
API documentation endpoints are disabled in production.

### Render free preview

Render's free web services sleep after 15 minutes without traffic and lose local
files when they restart or redeploy. Free Render Postgres expires after 30 days.
Render's managed database service is PostgreSQL, while this application
currently uses MySQL; PostgreSQL cannot be substituted without a database
migration. The production API also requires persistent upload storage and
working email delivery. Render free services cannot use persistent disks or
send SMTP over ports 25, 465, or 587.

Because of these limits, do not use Render's free tier for real student
accounts, uploaded files, or other important data. A public deployment needs a
reachable managed MySQL database, persistent file storage, an email provider
compatible with the host, and production secrets. Do not expose the XAMPP
database to the public internet or bypass the production checks to make a free
service start.

Use a unique, least-privilege app database user. The app user must not be a
database administrator. Apply schema migrations separately with a controlled
migration account, then run the service with `RUN_SCHEMA_MIGRATIONS=false`.
The development default runs additive `ensure_schema` migrations at startup;
the production path intentionally does not.

## 2. Database and secrets

- Keep MariaDB on a private network; allow inbound database access only from
  the API host.
- Use TLS for database connections when supported by the host.
- Restrict database accounts to the required host and privileges; replace all
  example passwords and `%` hosts in `database/database_users.sql`.
- Generate a unique `JWT_SECRET` for each environment and store it outside the
  repository. Do not reuse the development `.jwt_secret`.
- Keep email verification enabled and configure a verified SMTP sender.
- Limit access to database dumps and uploads; both may contain sensitive
  student information.

## 3. HTTPS, web, and mobile

- Terminate TLS at a maintained reverse proxy or managed platform, redirect
  HTTP to HTTPS, and forward `/api` requests only to the API service.
- Serve the built `web/dist` directory from the HTTPS web host. Do not use
  Vite's development server in production.
- The GitHub Pages workflow builds the React app at
  `https://<owner>.github.io/adviserlink/` and the Flutter web app at
  `https://<owner>.github.io/adviserlink/mobile/`. Configure the repository
  Actions variable `API_BASE_URL` with the HTTPS API origin only (no `/api`
  suffix). The API must allow the Pages origin in `CORS_ORIGINS`. GitHub Pages
  hosts static files only; it does not run the API or MySQL. The Pages workflow
  must be committed to the repository, Pages must be enabled for GitHub
  Actions, and an API URL must be configured before its build can succeed.
- For a temporary demo, Cloudflare Quick Tunnels can expose the local API at
  an HTTPS `trycloudflare.com` URL. Anyone with that URL can reach the API,
  the URL changes when the tunnel restarts, and the tunnel works only while
  the PC and API are running. Update `API_BASE_URL` and redeploy Pages when
  the URL changes. This is for testing only; use an isolated demo database and
  never expose real student data or the development database.
- For Cloudflare Pages, set the project root to `web`, build command to
  `npm run build`, and output directory to `dist`. Set the Pages environment
  variable `API_ORIGIN` to the Railway API's public HTTPS origin (origin only,
  with no `/api` path). The Pages Function in `web/functions/api/[[path]].js`
  forwards `/api/*` requests and profile-photo downloads to the API, keeping
  browser requests same-origin. Set `APP_BASE_URL` and `CORS_ORIGINS` to the
  final HTTPS website origin in the Railway service.
- For Railway, set the service root directory to `backend` and deploy using
  `backend/Dockerfile`. Attach a persistent volume and set `UPLOAD_DIR` to a
  directory inside its mount path (for example, `/data/uploads` if the volume
  is mounted at `/data`). Add a MySQL service and configure `DATABASE_URL`
  using a least-privilege app account after applying migrations with a separate
  migration account.
- Restrict API network exposure to the reverse proxy; do not expose the
  development API docs or bind the database publicly.
- Build Flutter with the HTTPS API URL, for example:

  ```powershell
  flutter build apk --release --dart-define=API_BASE_URL=https://api.example.edu
  ```

- Do not enable Android cleartext traffic in release builds. The local
  emulator's `http://10.0.2.2:8000` URL is for development only.
- Configure and protect a dedicated Android release keystore before publishing
  or distributing the APK. Never distribute a debug-signed APK as an official
  release. Keep signing credentials outside source control and backed up
  securely.

## 4. Persistent uploads

Set `UPLOAD_DIR` to a persistent, non-web-root volume. Back it up with the
database, restrict filesystem permissions to the API service account, and
confirm the volume survives service/container redeployments. Profile-photo
URLs are served by the API; project documents must be fetched through their
authenticated download endpoints.

## 5. Backup and restore

Configure `ADVISERLINK_BACKUP_DIR`, `BACKUP_RETENTION_DAYS`, and
`MYSQLDUMP_PATH` as appropriate. Run `database/backup_database.ps1` or the
Python backup command, inspect the checksum, and copy encrypted backups to a
separate failure domain. Schedule a restore test against a disposable database
regularly. See [database/BACKUP_RECOVERY.md](./database/BACKUP_RECOVERY.md).

## 6. Release checks

Before opening a deployment to users:

1. Apply migrations with the migration account and verify the DB schema.
2. Run backend tests: `python -m pytest tests -q`.
3. Build the web client: `npm run build`.
4. Verify the Pages `/api/health` proxy, registration, verification email,
   login, reset password, document access control, group invitations, bookings,
   and notifications over HTTPS.
5. Test backup restore in isolation; confirm the persistent upload volume is
   included in the recovery plan.
6. Confirm no secrets, `.env`, dumps, or user uploads are tracked by Git.
7. Configure monitoring for API errors, DB availability, disk capacity, backup
   age, and failed email delivery.

Do not treat a successful build or a checksum as proof that production
recovery works. Keep a documented owner and rollback plan for every release.
