"""
Small security helpers (pure Python, easy to test):
  - LoginThrottle: blocks repeated wrong passwords (brute force)
  - file_matches_type: checks actual file content, not just extension
"""
import time

_ZIP = (b"PK\x03\x04", b"PK\x05\x06")
_OLE = (b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1",)  # lumang Word/Excel/PowerPoint (.doc .xls .ppt)
SIGNATURES = {
    "pdf": (b"%PDF",),
    "png": (b"\x89PNG\r\n\x1a\n",),
    "jpg": (b"\xff\xd8\xff",),
    "jpeg": (b"\xff\xd8\xff",),
    "zip": _ZIP,
    "docx": _ZIP, "xlsx": _ZIP, "pptx": _ZIP,   # ang bagong Office files ay naka-zip
    "doc": _OLE, "xls": _OLE, "ppt": _OLE,
}


def file_matches_type(ext: str, head: bytes) -> bool:
    """True if the file's start matches what its extension claims."""
    ext = ext.lower()
    if ext == "txt":
        return b"\x00" not in head  # ang tunay na text file ay walang NUL bytes
    sigs = SIGNATURES.get(ext)
    return bool(sigs) and any(head.startswith(s) for s in sigs)


class LoginThrottle:
    """After `max_attempts` failures within `window` seconds, locked for `lock` seconds."""

    def __init__(self, max_attempts: int = 5, window: int = 600, lock: int = 600):
        self.max_attempts, self.window, self.lock = max_attempts, window, lock
        self._fails = {}

    def retry_after(self, key: str, now: float = None) -> int:
        """Seconds until login is allowed again (0 if allowed now)."""
        now = time.time() if now is None else now
        fails = [t for t in self._fails.get(key, []) if now - t < self.window]
        self._fails[key] = fails
        if len(fails) >= self.max_attempts:
            left = self.lock - (now - fails[-1])
            if left > 0:
                return int(left) + 1
            self._fails[key] = []
        return 0

    def fail(self, key: str, now: float = None) -> None:
        self._fails.setdefault(key, []).append(time.time() if now is None else now)

    def reset(self, key: str) -> None:
        self._fails.pop(key, None)
