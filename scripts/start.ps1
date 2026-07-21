param(
    [switch]$PreflightOnly
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $projectRoot ".venv-launcher\Scripts\python.exe"
$pythonw = Join-Path $projectRoot ".venv-launcher\Scripts\pythonw.exe"
$launcher = Join-Path $projectRoot "launcher.pyw"
$preflightScript = Join-Path $PSScriptRoot "preflight.py"
$setupScript = Join-Path $PSScriptRoot "setup.ps1"
$appIcon = Join-Path $projectRoot "assets\powerocr-icon.ico"

# Keep the existing desktop launcher in sync with the application's icon.
# This is best-effort so a missing/locked shortcut never blocks startup.
try {
    $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "OCRPDF-TO-PPT.lnk"
    if ((Test-Path -LiteralPath $desktopShortcut) -and (Test-Path -LiteralPath $appIcon)) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($desktopShortcut)
        # WScript expects an unquoted `path,index` value.  Quoting the path
        # makes Explorer treat the location as invalid and show a blank icon.
        $shortcut.IconLocation = ('{0},0' -f $appIcon)
        $shortcut.Save()
    }
}
catch {
    # Shortcut customization is cosmetic; continue to launch the application.
}

function Show-LaunchError([string]$message) {
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            $message,
            "OCRPDF-TO-PPT",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    catch {
        Write-Host $message
    }
}

if (-not (Test-Path -LiteralPath $launcher) -or -not (Test-Path -LiteralPath $preflightScript) -or -not (Test-Path -LiteralPath $setupScript)) {
    Show-LaunchError "One or more launcher files are missing. Please restore the project files."
    exit 1
}

function Invoke-EnvironmentSetup {
    try {
        Write-Host "Preparing the project-local Python environment ..." -ForegroundColor Cyan
        & $setupScript | Out-Host
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Invoke-Preflight {
    if (-not (Test-Path -LiteralPath $python) -or -not (Test-Path -LiteralPath $pythonw)) {
        return [pscustomobject]@{ Success = $false; Output = "The project-local virtual environment is missing." }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $python
    $startInfo.Arguments = ('"{0}"' -f $preflightScript)
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    try {
        $checkProcess = New-Object System.Diagnostics.Process
        $checkProcess.StartInfo = $startInfo
        [void]$checkProcess.Start()
        $checkStdout = $checkProcess.StandardOutput.ReadToEnd()
        $checkStderr = $checkProcess.StandardError.ReadToEnd()
        $checkProcess.WaitForExit()
        return [pscustomobject]@{
            Success = ($checkProcess.ExitCode -eq 0)
            Output = ($checkStdout + "`n" + $checkStderr).Trim()
        }
    }
    catch {
        return [pscustomobject]@{ Success = $false; Output = $_.Exception.Message }
    }
}

$env:VIRTUAL_ENV = Join-Path $projectRoot ".venv-launcher"
$env:PYTHONNOUSERSITE = "1"

$check = Invoke-Preflight
if (-not $check.Success) {
    Write-Host "Environment check failed: $($check.Output)" -ForegroundColor Yellow
    if (-not (Invoke-EnvironmentSetup)) {
        Show-LaunchError "The project-local environment could not be prepared. Install Python 3.13 or run the dependency repair BAT file and review the displayed error."
        exit 1
    }
    $check = Invoke-Preflight
    if (-not $check.Success) {
        Show-LaunchError ("Environment check still fails after repair:`n" + $check.Output)
        exit 1
    }
}

$env:Path = ((Join-Path $env:VIRTUAL_ENV "Scripts") + ";" + $env:Path)

if ($PreflightOnly) {
    Write-Host "Environment preflight succeeded: $projectRoot" -ForegroundColor Green
    exit 0
}

Start-Process -FilePath $pythonw `
    -ArgumentList ('"{0}"' -f $launcher) `
    -WorkingDirectory $projectRoot `
    -WindowStyle Hidden
