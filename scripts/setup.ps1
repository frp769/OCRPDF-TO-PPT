$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$venvDir = Join-Path $projectRoot ".venv-launcher"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$requirements = Join-Path $projectRoot "requirements.txt"
$python313 = Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"

Write-Host "OCRPDF-TO-PPT environment setup" -ForegroundColor Cyan
Write-Host "Project: $projectRoot"

if (-not (Test-Path -LiteralPath $python313)) {
    Write-Host "Python 3.13 was not found." -ForegroundColor Yellow
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  winget install --exact --id Python.Python.3.13 --scope user" -ForegroundColor White
    exit 1
}

$recreate = $false
if (Test-Path -LiteralPath $venvPython) {
    $version = & $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
    if ($LASTEXITCODE -ne 0 -or $version -ne "3.13") {
        $recreate = $true
    }
}
elseif (Test-Path -LiteralPath $venvDir) {
    $recreate = $true
}

if ($recreate) {
    $resolvedRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
    $resolvedVenv = [System.IO.Path]::GetFullPath($venvDir)
    if (-not $resolvedVenv.StartsWith($resolvedRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace a virtual environment outside the project directory."
    }
    Write-Host "Replacing incompatible .venv-launcher ..." -ForegroundColor Yellow
    Remove-Item -LiteralPath $resolvedVenv -Recurse -Force
}

if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host "Creating Python 3.13 virtual environment ..."
    & $python313 -m venv $venvDir
    if ($LASTEXITCODE -ne 0) { throw "Failed to create the virtual environment." }
}

Write-Host "Installing dependencies (the first run can take several minutes) ..."
& $venvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "Failed to upgrade pip." }

& $venvPython -m pip uninstall -y opencv-python
& $venvPython -m pip install -r $requirements
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed." }

# opencv-python and opencv-contrib-python share the same cv2 files. Reinstall the
# single selected distribution after removing the conflicting package.
& $venvPython -m pip install --force-reinstall --no-deps "opencv-contrib-python==4.10.0.84"
if ($LASTEXITCODE -ne 0) { throw "OpenCV repair failed." }

& $venvPython -m pip check
if ($LASTEXITCODE -ne 0) { throw "pip reported dependency conflicts." }

& $venvPython -c "import PySide6, qtawesome, paddle, paddleocr, cv2, pptx, PIL, fitz, requests; print('All required imports succeeded.')"
if ($LASTEXITCODE -ne 0) { throw "One or more required modules could not be imported." }

Write-Host ""
Write-Host "Setup completed. You can now use the one-click launch BAT file." -ForegroundColor Green
