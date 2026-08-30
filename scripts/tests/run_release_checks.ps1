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

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$releaseRoot = Join-Path $tempRoot ("five-minute-overdrive-release-{0}" -f [guid]::NewGuid().ToString("N"))
$releaseRoot = [System.IO.Path]::GetFullPath($releaseRoot)
if (-not $releaseRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Release-check path escaped the system temporary directory: $releaseRoot"
}

$packPath = Join-Path $releaseRoot "five-minute-overdrive.pck"
$logPath = Join-Path $releaseRoot "startup.log"
$forbidden = "SCRIPT ERROR|ERROR:|ObjectDB instances were leaked|RID.+leaked|resources still in use"
$maxPackBytes = 30MB
$forbiddenExportEntries = @(
    "res://assets/art/source/",
    "res://assets/art/actors/player/action_slices/",
    "res://assets/art/actors/player/direction_previews/",
    "res://assets/art/actors/player/directions/",
    "res://assets/art/actors/player/samples/",
    "res://assets/art/actors/player/technical_previews/",
    "res://assets/art/actors/player/turnaround_directions/",
    "res://scripts/art/",
    "res://scripts/tests/"
)

New-Item -ItemType Directory -Path $releaseRoot | Out-Null
try {
    Push-Location $projectRoot
    try {
        $exportOutput = & $godot --headless --audio-driver Dummy --path . --export-pack "Windows Desktop" $packPath 2>&1
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $packPath)) {
            throw "Windows PCK export failed:`n$($exportOutput -join [Environment]::NewLine)"
        }
        $exportTranscript = $exportOutput -join [Environment]::NewLine
        foreach ($forbiddenEntry in $forbiddenExportEntries) {
            if ($exportTranscript.IndexOf($forbiddenEntry, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "Windows PCK export included authoring-only content: $forbiddenEntry"
            }
        }
    }
    finally {
        Pop-Location
    }

    $packSize = (Get-Item -LiteralPath $packPath).Length
    if ($packSize -le 0) {
        throw "Windows PCK export produced an empty file."
    }
    if ($packSize -gt $maxPackBytes) {
        throw ("Windows PCK {0:N0} bytes exceeds the {1:N0}-byte release budget." -f $packSize, $maxPackBytes)
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $godot
    $startInfo.WorkingDirectory = $releaseRoot
    $startInfo.Arguments = "--headless --audio-driver Dummy --main-pack `"$packPath`" --log-file `"$logPath`" --quit-after 120"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw "Exported PCK startup timed out after 60 seconds."
    }
    $startupOutput = if (Test-Path -LiteralPath $logPath) { Get-Content -Raw -LiteralPath $logPath } else { "" }
    if ($process.ExitCode -ne 0) {
        throw "Exported PCK startup exited with $($process.ExitCode):`n$startupOutput"
    }
    if ($startupOutput -match $forbidden) {
        throw "Exported PCK startup emitted a forbidden error or leak marker:`n$startupOutput"
    }

    Write-Output ("RELEASE CHECK PASS: Windows PCK {0:N0} bytes, main scene ran 120 frames" -f $packSize)
}
finally {
    $resolvedReleaseRoot = [System.IO.Path]::GetFullPath($releaseRoot)
    if ($resolvedReleaseRoot.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedReleaseRoot)) {
        Remove-Item -LiteralPath $resolvedReleaseRoot -Recurse -Force
    }
}
