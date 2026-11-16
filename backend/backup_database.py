"""Create a verified full backup of the configured AdviserLink database."""
import argparse
import hashlib
import os
import shutil
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy.engine import make_url


BACKEND_DIR = Path(__file__).resolve().parent
load_dotenv(BACKEND_DIR / ".env")
CRITICAL_TABLES = ("users", "applications", "bookings", "adviser_profiles")


def find_mysqldump() -> str:
    configured = os.getenv("MYSQLDUMP_PATH", "").strip()
    if configured:
        path = Path(configured)
        if not path.is_file():
            raise RuntimeError(f"MYSQLDUMP_PATH does not point to a file: {path}")
        return str(path)
    found = shutil.which("mysqldump")
    if found:
        return found
    xampp = Path(r"C:\xampp\mysql\bin\mysqldump.exe")
    if xampp.is_file():
        return str(xampp)
    raise RuntimeError("mysqldump was not found. Set MYSQLDUMP_PATH in backend/.env.")


def verify_dump(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError("mysqldump completed without creating a non-empty backup.")
    found = set()
    with path.open("r", encoding="utf-8", errors="replace") as dump:
        for line in dump:
            for table in CRITICAL_TABLES:
                if f"CREATE TABLE `{table}`" in line or f"INSERT INTO `{table}`" in line:
                    found.add(table)
            if len(found) == len(CRITICAL_TABLES):
                return
    missing = ", ".join(sorted(set(CRITICAL_TABLES) - found))
    raise RuntimeError(f"Backup is missing critical tables: {missing}")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError("DATABASE_URL is missing from backend/.env.")
    url = make_url(database_url)
    if url.drivername not in ("mysql", "mysql+pymysql", "mariadb", "mariadb+pymysql"):
        raise RuntimeError("Configured DATABASE_URL must use MySQL or MariaDB.")
    if not url.database or not url.username:
        raise RuntimeError("DATABASE_URL must include a database name and user.")

    backup_dir = Path(
        os.getenv("ADVISERLINK_BACKUP_DIR", str(Path.home() / "AdviserLinkBackups" / url.database))
    ).expanduser().resolve()
    retention_days = int(os.getenv("BACKUP_RETENTION_DAYS", "30"))
    if retention_days < 1:
        raise RuntimeError("BACKUP_RETENTION_DAYS must be at least 1.")
    backup_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = backup_dir / f"adviserlink_full_{stamp}.sql"
    checksum_path = backup_path.with_suffix(".sql.sha256")
    command = [
        find_mysqldump(),
        "--single-transaction",
        "--routines",
        "--triggers",
        "--events",
        "--hex-blob",
        f"--host={url.host or 'localhost'}",
        f"--port={url.port or 3306}",
        f"--user={url.username}",
        f"--result-file={backup_path}",
        url.database,
    ]
    environment = os.environ.copy()
    if url.password is not None:
        environment["MYSQL_PWD"] = url.password

    result = subprocess.run(command, capture_output=True, text=True, env=environment, check=False)
    if result.returncode:
        backup_path.unlink(missing_ok=True)
        raise RuntimeError(f"mysqldump failed: {result.stderr.strip() or result.returncode}")

    try:
        verify_dump(backup_path)
        checksum = sha256_file(backup_path)
        checksum_path.write_text(f"{checksum}  {backup_path.name}\n", encoding="ascii")
    except Exception:
        backup_path.unlink(missing_ok=True)
        checksum_path.unlink(missing_ok=True)
        raise

    cutoff = datetime.now().timestamp() - timedelta(days=retention_days).total_seconds()
    for old_backup in backup_dir.glob("adviserlink_full_*.sql"):
        if old_backup != backup_path and old_backup.stat().st_mtime < cutoff:
            old_backup.unlink()
            old_backup.with_suffix(".sql.sha256").unlink(missing_ok=True)

    print(f"Verified backup: {backup_path}")
    print(f"Size: {backup_path.stat().st_size} bytes")
    print(f"SHA256: {checksum}")
    print(f"Retention: {retention_days} days")
    return 0


if __name__ == "__main__":
    argparse.ArgumentParser(
        description="Create and verify a full backup of the configured AdviserLink database."
    ).parse_args()
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"Backup failed: {error}", file=sys.stderr)
        raise SystemExit(1)
