"""Regression checks for the Windows project-local launcher."""

from __future__ import annotations

import re
from pathlib import Path
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class LauncherPortabilityTests(unittest.TestCase):
    def _read(self, relative_path: str) -> str:
        return (PROJECT_ROOT / relative_path).read_text(encoding="utf-8")

    def test_batch_files_anchor_to_their_own_directory(self) -> None:
        for filename in ("一键启动 OCRPDF-TO-PPT.bat", "安装或修复依赖.bat"):
            content = self._read(filename)
            self.assertIn('%~dp0', content, filename)
            self.assertIn('cd /d "%~dp0"', content, filename)

    def test_powershell_scripts_use_project_local_environment(self) -> None:
        start = self._read("scripts/start.ps1")
        setup = self._read("scripts/setup.ps1")
        for filename, content in (("start.ps1", start), ("setup.ps1", setup)):
            self.assertIn("$PSScriptRoot", content, filename)
            self.assertIn('.venv-launcher', content, filename)
            self.assertIn('PYTHONNOUSERSITE', content, filename)
        self.assertIn('requirements.txt', setup)
        self.assertIn('Find-Python313', setup)
        self.assertIn('Invoke-EnvironmentSetup', start)
        self.assertIn('PreflightOnly', start)

    def test_launcher_sources_have_no_checkout_specific_absolute_path(self) -> None:
        paths = (
            "一键启动 OCRPDF-TO-PPT.bat",
            "安装或修复依赖.bat",
            "launcher.pyw",
            "scripts/start.ps1",
            "scripts/setup.ps1",
            "scripts/preflight.py",
        )
        absolute_checkout = re.compile(
            r"(?i)(?:[a-z]:\\(?:users\\[^\\\s]+|ocrpdf-to-ppt)|/home/[^/\s]+/)"
        )
        for relative_path in paths:
            content = self._read(relative_path)
            self.assertIsNone(absolute_checkout.search(content), relative_path)


if __name__ == "__main__":
    unittest.main()
