"""Fast dependency presence check used by the Windows launcher."""

from __future__ import annotations

import importlib.util


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
}


def main() -> None:
    missing = [
        package
        for package, module in REQUIRED_MODULES.items()
        if importlib.util.find_spec(module) is None
    ]
    if missing:
        raise SystemExit("Missing dependencies: " + ", ".join(missing))


if __name__ == "__main__":
    main()
