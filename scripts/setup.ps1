[CmdletBinding()]
param(
    [switch]$ForceDependencies,
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$runtimeDir = Join-Path $projectRoot ".runtime\python313"
$runtimePython = Join-Path $runtimeDir "python.exe"
$venvDir = Join-Path $projectRoot ".venv-launcher"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$venvPythonw = Join-Path $venvDir "Scripts\pythonw.exe"
$lockFile = Join-Path $projectRoot "requirements-lock-win10.txt"
$fallbackRequirements = Join-Path $projectRoot "requirements.txt"
$requirements = if (Test-Path -LiteralPath $lockFile) { $lockFile } else { $fallbackRequirements }
$pythonVersion = "3.13.14"
$pythonPackageUrl = "https://api.nuget.org/v3-flatcontainer/python/$pythonVersion/python.$pythonVersion.nupkg"
$pythonPackageSha256 = "9ac15cfa6cab1115c83d48f2af55c554efa4d1bb044bbc4ab1c9d17ad426e16c"
$env:PYTHONNOUSERSITE = "1"

function Assert-InsideProject([string]$path, [string]$label) {
    $resolvedRoot = $projectRoot.TrimEnd('\')
    $resolvedPath = [System.IO.Path]::GetFullPath($path).TrimEnd('\')
    if (-not $resolvedPath.StartsWith(
            $resolvedRoot + '\',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Refusing to modify $label outside the project directory: $resolvedPath"
    }
}

function Assert-SupportedHost {
    if ($env:OS -ne "Windows_NT") {
        throw "This launcher supports Windows only."
    }

    $version = [System.Environment]::OSVersion.Version
    if ($version.Major -lt 10 -or ($version.Major -eq 10 -and $version.Build -lt 17763)) {
        throw "Windows 10 version 1809 (build 17763) or newer is required."
    }
    if (-not [System.Environment]::Is64BitOperatingSystem) {
        throw "A 64-bit Windows installation is required."
    }

    $nativeArchitecture = $env:PROCESSOR_ARCHITEW6432
    if ([string]::IsNullOrWhiteSpace($nativeArchitecture)) {
        $nativeArchitecture = $env:PROCESSOR_ARCHITECTURE
    }
    if ($nativeArchitecture -ne "AMD64") {
        throw "Windows x64 is required. The PaddlePaddle dependency is not distributed for Windows ARM64."
    }
}

function Assert-ProjectWritable {
    $probePath = Join-Path $projectRoot (".ocrpdf-write-test-" + [System.Guid]::NewGuid().ToString("N") + ".tmp")
    try {
        [System.IO.File]::WriteAllText($probePath, "ok", (New-Object System.Text.UTF8Encoding($false)))
    }
    catch {
        throw "The project directory is not writable. Move it to a normal user folder and try again."
    }
    finally {
        if (Test-Path -LiteralPath $probePath) {
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
        }
    }

    try {
        $drive = New-Object System.IO.DriveInfo([System.IO.Path]::GetPathRoot($projectRoot))
        if ($drive.IsReady -and $drive.AvailableFreeSpace -lt 2GB) {
            throw "At least 2 GB of free disk space is required for the local runtime and dependencies."
        }
    }
    catch {
        if ($_.Exception.Message -like "At least 2 GB*") {
            throw
        }
        Write-Warning "Free disk space could not be measured; setup will continue."
    }
}

function Test-ExactPython([string]$executable) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        return $false
    }
    try {
        $probe = & $executable -c "import struct, sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}|{struct.calcsize(chr(80)) * 8}')" 2>$null
        return $LASTEXITCODE -eq 0 -and ([string]$probe).Trim() -eq "$pythonVersion|64"
    }
    catch {
        return $false
    }
}

function Download-FileWithRetry([string]$url, [string]$destination) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    $lastError = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Write-Host "Downloading official Python $pythonVersion runtime (attempt $attempt/3) ..."
            Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
            return
        }
        catch {
            $lastError = $_
            if ($attempt -lt 3) {
                Start-Sleep -Seconds (2 * $attempt)
            }
        }
    }
    throw "Could not download the official Python runtime package: $($lastError.Exception.Message)"
}

function Install-OfficialRuntime {
    Assert-InsideProject $runtimeDir "runtime"
    if (Test-Path -LiteralPath $runtimeDir) {
        Write-Host "Removing an incomplete project-local runtime ..." -ForegroundColor Yellow
        Remove-Item -LiteralPath $runtimeDir -Recurse -Force
    }

    $packagePath = Join-Path ([System.IO.Path]::GetTempPath()) (
        "python-$pythonVersion-x64-" + [System.Guid]::NewGuid().ToString("N") + ".zip"
    )
    $extractDir = Join-Path (Split-Path -Parent $runtimeDir) (
        "python313-extract-" + [System.Guid]::NewGuid().ToString("N")
    )
    Assert-InsideProject $extractDir "runtime extraction directory"
    try {
        Download-FileWithRetry $pythonPackageUrl $packagePath

        $actualHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $pythonPackageSha256) {
            throw "The Python NuGet package checksum does not match the pinned official package."
        }

        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
        Expand-Archive -LiteralPath $packagePath -DestinationPath $extractDir -Force

        $manifestPath = Join-Path $extractDir "python.nuspec"
        $toolsDir = Join-Path $extractDir "tools"
        if (
            -not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath (Join-Path $toolsDir "python.exe") -PathType Leaf)
        ) {
            throw "The Python package layout is invalid."
        }

        [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
        $metadata = $manifest.package.metadata
        if ($metadata.id -ne "python" -or $metadata.version -ne $pythonVersion) {
            throw "The Python package identity is invalid."
        }
        Move-Item -LiteralPath $toolsDir -Destination $runtimeDir
    }
    finally {
        if (Test-Path -LiteralPath $packagePath) {
            Remove-Item -LiteralPath $packagePath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $extractDir) {
            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-ExactPython $runtimePython)) {
        throw "The project-local Python runtime was installed but failed validation."
    }
}

function Repair-VenvConfig {
    if (-not (Test-Path -LiteralPath $venvDir -PathType Container)) {
        return
    }
    Assert-InsideProject $venvDir "virtual environment"
    $runtimeHome = [System.IO.Path]::GetDirectoryName($runtimePython)
    $config = @(
        "home = $runtimeHome"
        "include-system-site-packages = false"
        "version = $pythonVersion"
        "executable = $runtimePython"
        "command = $runtimePython -m venv $venvDir"
    ) -join [System.Environment]::NewLine
    [System.IO.File]::WriteAllText(
        (Join-Path $venvDir "pyvenv.cfg"),
        $config + [System.Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Test-AppEnvironment {
    if (
        -not (Test-Path -LiteralPath $venvPython -PathType Leaf) -or
        -not (Test-Path -LiteralPath $venvPythonw -PathType Leaf)
    ) {
        return $false
    }
    try {
        Repair-VenvConfig
        $probeCode = "import os, struct, sys; expected=os.path.normcase(os.path.realpath(sys.argv[1])); actual=os.path.normcase(os.path.realpath(sys.base_prefix)); valid=(sys.version_info[:3]==(3,13,14) and struct.calcsize(chr(80))*8==64 and actual==expected); sys.exit(0 if valid else 3)"
        & $venvPython -c $probeCode $runtimeDir 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-RequiredImports {
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $venvPython
        $startInfo.Arguments = '-c "import PySide6, qtawesome, paddle, paddleocr, cv2, pptx, PIL, fitz, requests, image_utils, ppt_export, ocr_engine"'
        $startInfo.WorkingDirectory = $projectRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        [void]$stdoutTask.Result
        [void]$stderrTask.Result
        return $process.ExitCode -eq 0
    }
    catch {
        return $false
    }
}

Write-Host "OCRPDF-TO-PPT environment setup" -ForegroundColor Cyan
Write-Host "Project: $projectRoot"

Assert-SupportedHost
Assert-ProjectWritable
if (-not (Test-Path -LiteralPath $requirements -PathType Leaf)) {
    throw "No dependency requirements file was found in the project directory."
}

if (-not (Test-ExactPython $runtimePython)) {
    if ($CheckOnly) {
        Write-Host "The project-local Python $pythonVersion runtime is missing or invalid." -ForegroundColor Yellow
        exit 2
    }
    Install-OfficialRuntime
}
Write-Host "Runtime: $runtimePython"

if (-not (Test-AppEnvironment)) {
    if ($CheckOnly) {
        Write-Host "The project-local virtual environment is missing or invalid." -ForegroundColor Yellow
        exit 2
    }
    Assert-InsideProject $venvDir "virtual environment"
    if (Test-Path -LiteralPath $venvDir) {
        Write-Host "Replacing an incompatible project-local virtual environment ..." -ForegroundColor Yellow
        Remove-Item -LiteralPath $venvDir -Recurse -Force
    }
    Write-Host "Creating the project-local virtual environment ..."
    & $runtimePython -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the project-local virtual environment."
    }
    Repair-VenvConfig
}

$env:VIRTUAL_ENV = $venvDir
$env:Path = ((Join-Path $venvDir "Scripts") + ";" + $env:Path)

if ($CheckOnly) {
    & $venvPython -m pip check
    if ($LASTEXITCODE -ne 0 -or -not (Test-RequiredImports)) {
        Write-Host "The dependency environment needs repair." -ForegroundColor Yellow
        exit 2
    }
    Write-Host "Environment check completed successfully." -ForegroundColor Green
    exit 0
}

if ($ForceDependencies -or -not (Test-RequiredImports)) {
    Write-Host "Installing locked dependencies (the first run can take several minutes) ..."
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upgrade pip."
    }

    & $venvPython -m pip uninstall -y opencv-python opencv-python-headless
    & $venvPython -m pip install -r $requirements
    if ($LASTEXITCODE -ne 0) {
        throw "Dependency installation failed."
    }

    # OpenCV distributions share the same cv2 files. Reinstall the selected
    # contrib build after removing conflicting variants.
    & $venvPython -m pip install --force-reinstall --no-deps "opencv-contrib-python==4.10.0.84"
    if ($LASTEXITCODE -ne 0) {
        throw "OpenCV repair failed."
    }
}

& $venvPython -m pip check
if ($LASTEXITCODE -ne 0) {
    throw "pip reported dependency conflicts."
}
if (-not (Test-RequiredImports)) {
    throw "One or more required application modules could not be imported."
}

Write-Host ""
Write-Host "Setup completed. You can now use the one-click launch BAT file." -ForegroundColor Green
