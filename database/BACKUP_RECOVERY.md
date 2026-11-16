# AdviserLink database backup and restore

## Create and verify a backup

The backend backup tool reads `DATABASE_URL` from `backend/.env`; it never puts the database password in the command line.

```powershell
cd C:\xampp\adviserlink\backend
.\venv\Scripts\python.exe backup_database.py
```

By default, verified dumps and SHA-256 sidecars are saved under
`%USERPROFILE%\AdviserLinkBackups\<database-name>`. Configure
`ADVISERLINK_BACKUP_DIR`, `BACKUP_RETENTION_DAYS` (30 by default), or
`MYSQLDUMP_PATH` in `backend/.env` as needed. The script checks that the dump
is non-empty and contains the critical AdviserLink tables before keeping it.
It removes only old AdviserLink full-dump files it created in the configured
backup directory.

To run a daily task at 2:00 AM for the current Windows user:

```powershell
.\database\register_backup_task.ps1
```

The task runs only while that user is signed in. Review Task Scheduler history
and confirm backup files are being created. Backups on the same PC do not
protect against disk loss; copy them to encrypted off-device storage using a
separately secured process. Never commit `.env` files or backup dumps.

## Restore to a separate test database

First verify the `.sha256` sidecar and ensure MariaDB is running. Then create a
new, empty test database and restore the dump there. Do not test by restoring
over `adviserlink_db`.

```powershell
$dump = "C:\Users\<you>\AdviserLinkBackups\adviserlink_db\adviserlink_full_<timestamp>.sql"
$mysql = "C:\xampp\mysql\bin\mysql.exe"
& $mysql -u root -p -e "CREATE DATABASE adviserlink_restore_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
if ($LASTEXITCODE -ne 0) { throw "Could not create the isolated restore database." }
$command = "`"$mysql`" -u root -p adviserlink_restore_test < `"$dump`""
& $env:ComSpec /c $command
if ($LASTEXITCODE -ne 0) { throw "Restore failed; keep the test database for diagnosis." }
```

The dump contains only the configured database's objects and data, so the
target database must exist before restore. Do not run unreviewed restore
commands against the live database. Compare table counts and exercise login,
application, booking, and document flows against the test instance before
considering recovery complete. Drop the test database only after completing
the restore test and confirming the correct database name.

## Recovery cautions

- Stop the API before a live restore and take a fresh copy of the current
  database files or dump first.
- Never restore a backup over the live database without explicit approval and
  a verified recovery plan.
- Keep backups access-controlled and encrypted at rest; they contain personal
  and project data.
- Periodically perform a restore test in an isolated database. A checksum
  verifies file integrity, not that the database can be restored.
- The legacy `backup_demo.ps1` / `backup_demo.sh` names now invoke the safe
  backup command only; they no longer create or delete test databases.
