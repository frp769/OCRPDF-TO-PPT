"""Fast runtime and dependency checks used by the Windows launcher."""

from __future__ import annotations

import importlib.util
import platform
import struct
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

REQUIRED_MODULES = {
    "PySide6": "PySide6",
    "QtAwesome": "qtawesome",
    "PaddleOCR": "paddleocr",
    "PaddlePaddle": "paddle",
    "OpenCV": "cv2",
    "python-pptx": "pptx",
    "Pillow": "PIL",
    "PyMuPDF": "fitz",
    "requests": "requests",
    "image utilities": "image_utils",
    "PPT exporter": "ppt_export",
    "OCR engine": "ocr_engine",
}


def collect_errors() -> list[str]:
    errors: list[str] = []

    if sys.version_info[:2] != (3, 13):
        errors.append(
            f"Python 3.13 is required; found {platform.python_version()} at {sys.executable}"
        )
    if struct.calcsize("P") * 8 != 64:
        errors.append("A 64-bit Python runtime is required.")

    if sys.platform == "win32":
        windows = sys.getwindowsversion()
        if windows.major < 10 or (windows.major == 10 and windows.build < 17763):
            errors.append(
                f"Windows 10 build 17763 or newer is required; found build {windows.build}."
            )
        if platform.machine().lower() not in {"amd64", "x86_64"}:
            errors.append(
                f"Windows x64 is required; found architecture {platform.machine() or 'unknown'}."
            )

    if not (PROJECT_ROOT / "main.py").is_file():
        errors.append(f"Project root could not be resolved from {__file__}.")

    missing = [
        package
        for package, module in REQUIRED_MODULES.items()
        if importlib.util.find_spec(module) is None
    ]
    if missing:
        errors.append("Missing dependencies: " + ", ".join(missing))

    return errors


def main() -> None:
    errors = collect_errors()
    if errors:
        raise SystemExit("\n".join(f"- {error}" for error in errors))
    print(
        "Preflight OK: "
        f"Python {platform.python_version()} 64-bit, "
        f"{platform.system()} {platform.release()}, "
        f"project={PROJECT_ROOT}"
    )


if __name__ == "__main__":
    main()
