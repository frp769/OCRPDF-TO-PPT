"""Crash-safe JSON persistence helpers for local application settings."""

from __future__ import annotations

import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any


def load_json_with_backup(path: str | os.PathLike[str]) -> tuple[dict[str, Any], bool]:
    """Load a JSON object, falling back to ``<path>.bak`` when necessary.

    Returns ``(data, recovered_from_backup)``. Missing primary and backup files
    are treated as an empty object; malformed files raise the last JSON error.
    """

    target = Path(path)
    backup = Path(f"{target}.bak")
    last_error: Exception | None = None

    for candidate, recovered in ((target, False), (backup, True)):
        if not candidate.exists():
            continue
        try:
            with candidate.open("r", encoding="utf-8") as handle:
                data = json.load(handle)
            if not isinstance(data, dict):
                raise ValueError(f"{candidate.name} must contain a JSON object")
            return data, recovered
        except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as exc:
            last_error = exc

    if last_error is not None:
        raise last_error
    return {}, False


def atomic_write_json(path: str | os.PathLike[str], data: dict[str, Any]) -> None:
    """Atomically replace a JSON file and retain its last valid version."""

    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    backup = Path(f"{target}.bak")

    if target.exists():
        try:
            with target.open("r", encoding="utf-8") as handle:
                current = json.load(handle)
            if isinstance(current, dict):
                backup_fd, backup_name = tempfile.mkstemp(
                    prefix=f".{target.name}.",
                    suffix=".bak.tmp",
                    dir=target.parent,
                )
                os.close(backup_fd)
                try:
                    shutil.copyfile(target, backup_name)
                    os.replace(backup_name, backup)
                finally:
                    if os.path.exists(backup_name):
                        os.unlink(backup_name)
        except (OSError, UnicodeError, ValueError, json.JSONDecodeError):
            # Never overwrite a known-good backup with a corrupt primary file.
            pass

    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.",
        suffix=".tmp",
        dir=target.parent,
    )
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, target)
    finally:
        if os.path.exists(temporary_name):
            os.unlink(temporary_name)
