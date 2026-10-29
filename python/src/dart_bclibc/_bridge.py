"""Client of tool/py_bridge/bridge.dart: one long-lived Dart process, one JSON line per request.

The process is started lazily, shared by every engine in this Python process, and restarted if it dies.
`DART_BCLIBC_BRIDGE` overrides the command (a shell-style string), `DART_BCLIBC_ROOT` the dart-bclibc
checkout it is run from (default: the checkout this package sits in).
"""

from __future__ import annotations

import atexit
import json
import os
import shlex
import shutil
import subprocess
import threading
from pathlib import Path
from typing import Any

__all__ = ("BridgeError", "BridgeProcess", "BridgeReplyError", "bridge", "package_root")

_BRIDGE_SCRIPT = Path("tool") / "py_bridge" / "bridge.dart"


class BridgeError(RuntimeError):
    """The bridge failed in a way that is not a solver error (it died, spoke garbage, ...)."""


def package_root() -> Path:
    """The dart-bclibc checkout holding pubspec.yaml and tool/py_bridge."""
    env = os.environ.get("DART_BCLIBC_ROOT")
    if env:
        return Path(env).resolve()
    for parent in Path(__file__).resolve().parents:
        if (parent / "pubspec.yaml").is_file() and (parent / _BRIDGE_SCRIPT).is_file():
            return parent
    raise BridgeError("Cannot find the dart-bclibc checkout; set DART_BCLIBC_ROOT")


def _command(root: Path) -> list[str]:
    custom = os.environ.get("DART_BCLIBC_BRIDGE")
    if custom:
        return shlex.split(custom)
    dart = shutil.which("dart")
    if dart is None:
        raise BridgeError("`dart` is not on PATH; install the Dart SDK or set DART_BCLIBC_BRIDGE")
    return [dart, "run", str(root / _BRIDGE_SCRIPT)]


class BridgeProcess:
    """A running bridge.dart; `request` is safe to call from several threads."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._proc: subprocess.Popen[str] | None = None
        self._next_id = 0

    def _start(self) -> subprocess.Popen[str]:
        root = package_root()
        return subprocess.Popen(
            _command(root),
            cwd=root,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=None,  # the bridge's diagnostics go straight to ours
            text=True,
            encoding="utf-8",
            bufsize=1,
        )

    def _read_reply(self, proc: subprocess.Popen[str], req_id: int) -> dict[str, Any]:
        assert proc.stdout is not None
        while True:
            line = proc.stdout.readline()
            if not line:
                raise BridgeError(f"dart bridge exited (code {proc.poll()}) before answering request {req_id}")
            line = line.strip()
            if not line.startswith("{"):
                continue  # build-hook chatter from `dart run`
            reply = json.loads(line)
            if reply.get("id") == req_id:
                return reply

    def request(self, op: str, **payload: Any) -> dict[str, Any]:
        """Send one request; returns the `result` dict, or raises BridgeReplyError for an error reply."""
        with self._lock:
            if self._proc is None or self._proc.poll() is not None:
                self._proc = self._start()
            proc = self._proc
            self._next_id += 1
            req_id = self._next_id
            assert proc.stdin is not None
            try:
                # allow_nan=False: callers map NaN/inf to None themselves; a stray one must not reach Dart's parser
                proc.stdin.write(json.dumps({"id": req_id, "op": op, **payload}, allow_nan=False) + "\n")
                proc.stdin.flush()
                reply = self._read_reply(proc, req_id)
            except (BrokenPipeError, BridgeError):
                self._proc = None
                raise
        if not reply.get("ok"):
            raise BridgeReplyError(reply["error"])
        return reply["result"]

    def close(self) -> None:
        with self._lock:
            proc, self._proc = self._proc, None
        if proc is None:
            return
        try:
            if proc.stdin:
                proc.stdin.close()
            proc.wait(timeout=60)  # `dart run` under the coverage collector needs a moment to hand over its data
        except Exception:  # noqa: BLE001 -- shutting down; make sure it is gone
            proc.kill()
        finally:
            if proc.stdout:
                proc.stdout.close()


class BridgeReplyError(Exception):
    """An `ok: false` reply; `.error` is the bridge's error object (kind, message, ...)."""

    def __init__(self, error: dict[str, Any]) -> None:
        super().__init__(error.get("message", ""))
        self.error = error


_shared = BridgeProcess()
atexit.register(_shared.close)


def bridge() -> BridgeProcess:
    return _shared
