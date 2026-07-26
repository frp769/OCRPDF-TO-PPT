[CmdletBinding()]
param(
    [switch]$PreflightOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$runtimeDir = Join-Path $projectRoot ".runtime\python313"
$runtimePython = Join-Path $runtimeDir "python.exe"
$venvDir = Join-Path $projectRoot ".venv-launcher"
$python = Join-Path $venvDir "Scripts\python.exe"
$pythonw = Join-Path $venvDir "Scripts\pythonw.exe"
$launcher = Join-Path $projectRoot "launcher.pyw"
$preflightScript = Join-Path $PSScriptRoot "preflight.py"
$setupScript = Join-Path $PSScriptRoot "setup.ps1"
$appIcon = Join-Path $projectRoot "assets\powerocr-icon.ico"
$expectedPythonVersion = "3.13.14"

# Keep the existing desktop launcher in sync with the application's icon.
# This is best-effort so a missing or locked shortcut never blocks startup.
try {
    $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "OCRPDF-TO-PPT.lnk"
    if ((Test-Path -LiteralPath $desktopShortcut) -and (Test-Path -LiteralPath $appIcon)) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($desktopShortcut)
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
        Write-Host $message -ForegroundColor Red
    }
}

function Repair-VenvConfig {
    if (
        -not (Test-Path -LiteralPath $runtimePython -PathType Leaf) -or
        -not (Test-Path -LiteralPath $venvDir -PathType Container)
    ) {
        return $false
    }
    try {
        $probe = & $runtimePython -c "import struct, sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}|{struct.calcsize(chr(80)) * 8}')" 2>$null
        if ($LASTEXITCODE -ne 0 -or ([string]$probe).Trim() -ne "$expectedPythonVersion|64") {
            return $false
        }

        $resolvedRoot = $projectRoot.TrimEnd('\')
        $resolvedVenv = [System.IO.Path]::GetFullPath($venvDir).TrimEnd('\')
        if (-not $resolvedVenv.StartsWith(
                $resolvedRoot + '\',
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            return $false
        }

        $config = @(
            "home = $runtimeDir"
            "include-system-site-packages = false"
            "version = $expectedPythonVersion"
            "executable = $runtimePython"
            "command = $runtimePython -m venv $venvDir"
        ) -join [System.Environment]::NewLine
        [System.IO.File]::WriteAllText(
            (Join-Path $venvDir "pyvenv.cfg"),
            $config + [System.Environment]::NewLine,
            (New-Object System.Text.UTF8Encoding($false))
        )
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-EnvironmentSetup {
    try {
        Write-Host "Preparing the project-local Python environment ..." -ForegroundColor Cyan
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $setupScript
        return $LASTEXITCODE -eq 0
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Invoke-Preflight {
    if (
        -not (Test-Path -LiteralPath $python -PathType Leaf) -or
        -not (Test-Path -LiteralPath $pythonw -PathType Leaf)
    ) {
        return [pscustomobject]@{
            Success = $false
            Output = "The project-local virtual environment is missing."
        }
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
        return [pscustomobject]@{
            Success = $false
            Output = $_.Exception.Message
        }
    }
}

if (
    -not (Test-Path -LiteralPath $launcher -PathType Leaf) -or
    -not (Test-Path -LiteralPath $preflightScript -PathType Leaf) -or
    -not (Test-Path -LiteralPath $setupScript -PathType Leaf)
) {
    Show-LaunchError "One or more launcher files are missing. Please restore the project files."
    exit 1
}

if (-not (Repair-VenvConfig)) {
    if (-not (Invoke-EnvironmentSetup)) {
        Show-LaunchError "The project-local environment could not be prepared. Run the dependency repair BAT file and review the displayed error."
        exit 1
    }
    if (-not (Repair-VenvConfig)) {
        Show-LaunchError "The project-local Python runtime or virtual environment is still invalid after repair."
        exit 1
    }
}

$env:VIRTUAL_ENV = $venvDir
$env:PYTHONNOUSERSITE = "1"
$env:Path = ((Join-Path $venvDir "Scripts") + ";" + $env:Path)

$check = Invoke-Preflight
if (-not $check.Success) {
    Write-Host "Environment check failed: $($check.Output)" -ForegroundColor Yellow
    if (-not (Invoke-EnvironmentSetup)) {
        Show-LaunchError "The project-local environment could not be repaired. Run the dependency repair BAT file and review the displayed error."
        exit 1
    }
    if (-not (Repair-VenvConfig)) {
        Show-LaunchError "The virtual environment path could not be repaired after setup."
        exit 1
    }
    $check = Invoke-Preflight
    if (-not $check.Success) {
        Show-LaunchError ("Environment check still fails after repair:`n" + $check.Output)
        exit 1
    }
}

if ($PreflightOnly) {
    Write-Host "Environment preflight succeeded: $projectRoot" -ForegroundColor Green
    exit 0
}

Start-Process -FilePath $pythonw `
    -ArgumentList ('"{0}"' -f $launcher) `
    -WorkingDirectory $projectRoot `
    -WindowStyle Hidden
