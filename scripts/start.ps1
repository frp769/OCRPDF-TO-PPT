$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$python = Join-Path $projectRoot ".venv-launcher\Scripts\python.exe"
$pythonw = Join-Path $projectRoot ".venv-launcher\Scripts\pythonw.exe"
$launcher = Join-Path $projectRoot "launcher.pyw"
$preflightScript = Join-Path $PSScriptRoot "preflight.py"
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

if (-not (Test-Path -LiteralPath $python) -or -not (Test-Path -LiteralPath $pythonw)) {
    Show-LaunchError "The launch environment is missing. Run the dependency repair BAT file in the project folder first."
    exit 1
}

if (-not (Test-Path -LiteralPath $launcher) -or -not (Test-Path -LiteralPath $preflightScript)) {
    Show-LaunchError "One or more launcher files are missing. Please restore the project files."
    exit 1
}

$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = $python
$startInfo.Arguments = ('"{0}"' -f $preflightScript)
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true

$checkProcess = New-Object System.Diagnostics.Process
$checkProcess.StartInfo = $startInfo
[void]$checkProcess.Start()
$checkStdout = $checkProcess.StandardOutput.ReadToEnd()
$checkStderr = $checkProcess.StandardError.ReadToEnd()
$checkProcess.WaitForExit()

if ($checkProcess.ExitCode -ne 0) {
    $checkOutput = ($checkStdout + "`n" + $checkStderr).Trim()
    Show-LaunchError ("Environment check failed:`n" + $checkOutput + "`n`nRun the dependency repair BAT file, then try again.")
    exit 1
}

Start-Process -FilePath $pythonw `
    -ArgumentList ('"{0}"' -f $launcher) `
    -WorkingDirectory $projectRoot `
    -WindowStyle Hidden
