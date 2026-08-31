$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$winGetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
$godot = $env:GODOT_BIN

if ([string]::IsNullOrWhiteSpace($godot)) {
    $console = Get-ChildItem -Path $winGetRoot -Filter "Godot_v4.7-stable_win64_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $console) {
        $godot = $console.FullName
    }
}
if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path -LiteralPath $godot)) {
    throw "Godot 4.7 console executable was not found. Set GODOT_BIN to its full path."
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$releasePrefix = "five-minute-overdrive-windows-exe-"
$releaseRoot = Join-Path $tempRoot ($releasePrefix + [guid]::NewGuid().ToString("N"))
$releaseRoot = [System.IO.Path]::GetFullPath($releaseRoot)
$releaseParent = (Split-Path -Parent $releaseRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
$releaseLeaf = Split-Path -Leaf $releaseRoot
if (-not $releaseParent.Equals($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -or -not $releaseLeaf.StartsWith($releasePrefix, [System.StringComparison]::Ordinal)) {
    throw "Windows EXE check path escaped its dedicated temporary directory: $releaseRoot"
}

$exePath = Join-Path $releaseRoot "five-minute-overdrive.exe"
$packPath = Join-Path $releaseRoot "five-minute-overdrive.pck"
$logPath = Join-Path $releaseRoot "startup.log"
$forbidden = "SCRIPT ERROR|ERROR:|ObjectDB instances were leaked|RID.+leaked|resources still in use"
$maxPackBytes = 30MB

New-Item -ItemType Directory -Path $releaseRoot | Out-Null
try {
    Push-Location $projectRoot
    try {
        $exportOutput = & $godot --headless --audio-driver Dummy --path . --export-release "Windows Desktop" $exePath 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath) -or -not (Test-Path -LiteralPath $packPath)) {
            throw "Windows release export failed:`n$($exportOutput -join [Environment]::NewLine)"
        }
        $exportTranscript = $exportOutput -join [Environment]::NewLine
        if ($exportTranscript -match $forbidden) {
            throw "Windows release export emitted a forbidden error or leak marker:`n$exportTranscript"
        }
    }
    finally {
        Pop-Location
    }

    $exeSize = (Get-Item -LiteralPath $exePath).Length
    $packSize = (Get-Item -LiteralPath $packPath).Length
    if ($exeSize -le 0 -or $packSize -le 0) {
        throw "Windows release export produced an empty EXE or PCK."
    }
    if ($packSize -gt $maxPackBytes) {
        throw ("Windows PCK {0:N0} bytes exceeds the {1:N0}-byte release budget." -f $packSize, $maxPackBytes)
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $exePath
    $startInfo.WorkingDirectory = $releaseRoot
    $startInfo.Arguments = "--headless --audio-driver Dummy --log-file `"$logPath`" --quit-after 120"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw "Exported Windows EXE startup timed out after 60 seconds."
    }

    if (-not (Test-Path -LiteralPath $logPath)) {
        throw "Exported Windows EXE did not produce the required startup log."
    }
    $startupOutput = Get-Content -Raw -LiteralPath $logPath
    if ($process.ExitCode -ne 0) {
        throw "Exported Windows EXE exited with $($process.ExitCode):`n$startupOutput"
    }
    if ($startupOutput -match $forbidden) {
        throw "Exported Windows EXE emitted a forbidden error or leak marker:`n$startupOutput"
    }

    Write-Output ("WINDOWS EXE CHECK PASS: EXE {0:N0} bytes, PCK {1:N0} bytes, main scene ran 120 frames" -f $exeSize, $packSize)
}
finally {
    $resolvedReleaseRoot = [System.IO.Path]::GetFullPath($releaseRoot)
    $resolvedParent = (Split-Path -Parent $resolvedReleaseRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $resolvedLeaf = Split-Path -Leaf $resolvedReleaseRoot
    $safeToDelete = $resolvedParent.Equals($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $resolvedLeaf.StartsWith($releasePrefix, [System.StringComparison]::Ordinal)
    if ($safeToDelete -and (Test-Path -LiteralPath $resolvedReleaseRoot)) {
        Remove-Item -LiteralPath $resolvedReleaseRoot -Recurse -Force
    }
}
