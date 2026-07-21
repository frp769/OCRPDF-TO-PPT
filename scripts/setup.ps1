$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$venvDir = Join-Path $projectRoot ".venv-launcher"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$venvPythonw = Join-Path $venvDir "Scripts\pythonw.exe"
$requirements = Join-Path $projectRoot "requirements.txt"
$env:PYTHONNOUSERSITE = "1"

function Test-Python313([string]$executable, [string[]]$prefixArguments = @()) {
    if ([string]::IsNullOrWhiteSpace($executable)) {
        return $null
    }

    try {
        $probe = & $executable @prefixArguments -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}|{sys.executable}')" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($probe)) {
            return $null
        }
        $parts = ([string]$probe).Trim().Split('|', 2)
        if ($parts.Count -eq 2 -and $parts[0] -eq "3.13" -and (Test-Path -LiteralPath $parts[1])) {
            return [System.IO.Path]::GetFullPath($parts[1])
        }
    }
    catch {
        return $null
    }
    return $null
}

function Find-Python313 {
    $pyLauncher = Get-Command "py.exe" -ErrorAction SilentlyContinue
    if ($null -ne $pyLauncher) {
        $resolved = Test-Python313 $pyLauncher.Source @("-3.13")
        if ($null -ne $resolved) { return $resolved }
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $candidates += Join-Path $env:ProgramFiles "Python313\python.exe"
    }
    if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "Python313\python.exe"
    }
    foreach ($commandName in @("python3.13.exe", "python.exe")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) { $candidates += $command.Source }
    }

    foreach ($candidate in ($candidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $resolved = Test-Python313 $candidate
        if ($null -ne $resolved) { return $resolved }
    }
    return $null
}

function Test-ProjectVirtualEnvironment {
    if (-not (Test-Path -LiteralPath $venvPython) -or -not (Test-Path -LiteralPath $venvPythonw)) {
        return $false
    }
    try {
        $probe = & $venvPython -c "import os, sys; print(f'{sys.version_info.major}.{sys.version_info.minor}|{os.path.normcase(os.path.realpath(sys.prefix))}')" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($probe)) { return $false }
        $parts = ([string]$probe).Trim().Split('|', 2)
        $expectedPrefix = [System.IO.Path]::GetFullPath($venvDir).TrimEnd('\')
        return $parts.Count -eq 2 -and $parts[0] -eq "3.13" -and
            $parts[1].TrimEnd('\').Equals($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

Write-Host "OCRPDF-TO-PPT environment setup" -ForegroundColor Cyan
Write-Host "Project: $projectRoot"

if (-not (Test-Path -LiteralPath $requirements)) {
    throw "requirements.txt is missing from the project directory."
}

$python313 = Find-Python313
if ($null -eq $python313) {
    Write-Host "Python 3.13 was not found." -ForegroundColor Yellow
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  winget install --exact --id Python.Python.3.13 --scope user" -ForegroundColor White
    throw "Install Python 3.13, then run setup again."
}
Write-Host "Base Python: $python313"

$recreate = (Test-Path -LiteralPath $venvDir) -and -not (Test-ProjectVirtualEnvironment)

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

$env:VIRTUAL_ENV = $venvDir
$env:Path = ((Join-Path $venvDir "Scripts") + ";" + $env:Path)

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
