"""Windowless launcher with persistent startup error logging for Windows."""

from __future__ import annotations

import ctypes
import datetime as _datetime
import os
from pathlib import Path
import runpy
import sys
import traceback


PROJECT_ROOT = Path(__file__).resolve().parent
LOG_DIR = PROJECT_ROOT / "logs"
LOG_FILE = LOG_DIR / "launcher.log"


def _message_box(message: str, title: str = "OCRPDF-TO-PPT") -> None:
    try:
        ctypes.windll.user32.MessageBoxW(None, message, title, 0x10)
    except Exception:
        pass


def main() -> None:
    os.chdir(PROJECT_ROOT)
    os.environ.setdefault("PYTHONUTF8", "1")
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    with LOG_FILE.open("a", encoding="utf-8", buffering=1) as log:
        stamp = _datetime.datetime.now().isoformat(timespec="seconds")
        log.write(f"\n[{stamp}] Starting OCRPDF-TO-PPT\n")
        sys.stdout = log
        sys.stderr = log
        try:
            runpy.run_path(str(PROJECT_ROOT / "main.py"), run_name="__main__")
        except SystemExit as exc:
            if exc.code not in (None, 0):
                raise
        except BaseException:
            traceback.print_exc(file=log)
            _message_box(
                "程序启动失败。错误详情已写入：\n"
                f"{LOG_FILE}\n\n"
                "可双击“安装或修复依赖.bat”后重试。"
            )


if __name__ == "__main__":
    main()

