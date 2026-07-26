# OCRPDF-TO-PPT portability matrix

## Fully supported

| Area | Supported baseline |
| --- | --- |
| Operating system | Windows 10 version 1809 or later; Windows 11 |
| Architecture | Intel/AMD x86-64 |
| Python | Project-local CPython 3.13.14, installed automatically |
| PowerShell | Windows PowerShell 5.1 or PowerShell 7 |
| OCR | PaddlePaddle 3.3.1 CPU + PaddleOCR 3.7.0 |
| UI | PySide6 6.11.1 / Qt 6 |
| Paths | Local paths on any drive, including spaces and Chinese characters |
| Permissions | Standard user account with write access to the project folder |

The first repair downloads the official CPython x64 NuGet runtime with a pinned
SHA-256 checksum, then installs the versions in
`requirements-lock-win10.txt`. It does not require or reuse a system Python
installation. Afterwards, `.runtime`, `.venv-launcher`, and downloaded OCR
models can travel with the whole folder; startup repairs the virtual
environment paths after the folder is moved.

These large local directories are intentionally excluded from Git. A Git clone
or GitHub ZIP therefore performs the first repair on each computer, while a
complete copy of an already prepared local folder may reuse them.

## Supported with limitations

- Windows on a corporate network: configure the network/proxy so NuGet and PyPI
  are reachable during the first repair.
- OneDrive or another synchronized folder: usually works, but dependency
  installation is slower and file locking can interfere. A local NTFS folder is
  recommended.
- Network shares and removable drives: not part of the verified baseline.
- GPU OCR: optional and not installed by the repair script. The CPU build is the
  supported default.
- IOPaint: optional local service; OCR, editing, solid-fill cleaning, and PPT
  export work without it.

## Not supported

- Windows 7/8 and Windows 10 releases older than 1809.
- 32-bit Windows or 32-bit Python.
- Windows ARM64. Qt provides ARM64 builds, but the required PaddlePaddle Windows
  wheel is currently x86-64 only.
- Running the Windows BAT/PowerShell launchers on macOS or Linux.

## Verification levels

- `检查并修复程序.bat`: repairs the project-local runtime and all locked
  dependencies.
- `一键启动 OCRPDF-TO-PPT.bat`: repairs automatically when needed, runs the
  fast preflight, then starts the GUI.
- Automated tests cover internal imports, Unicode paths, settings recovery,
  editable PPTX output, launcher path anchoring, and offscreen Qt startup.

Physical testing on another machine is still the final proof for a particular
driver, antivirus, proxy, and filesystem combination.
