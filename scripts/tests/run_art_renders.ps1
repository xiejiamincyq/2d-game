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

Push-Location $projectRoot
try {
    $forbidden = "SCRIPT ERROR|ERROR:|ObjectDB instances were leaked|RID.+leaked|resources still in use"
    $importOutput = (& $godot --headless --path . --import 2>&1 | Out-String)
    $importExitCode = $LASTEXITCODE
    if ($importExitCode -ne 0 -or $importOutput -match $forbidden) {
        Write-Host "===== RESOURCE IMPORT FAILED =====" -ForegroundColor Red
        Write-Host $importOutput
        exit 1
    }
    Write-Host "RESOURCE IMPORT PASS" -ForegroundColor Green

    $gates = @(
        @{ Script = "RenderChibiRuntimePreview.gd"; Marker = "RENDER PASS: Chibi B runtime preview" },
        @{ Script = "RenderStaticEnemyRuntimePreview.gd"; Marker = "RENDER PASS: Static enemy runtime preview" },
        @{ Script = "RenderCombatVfxRuntimePreview.gd"; Marker = "RENDER PASS: Combat VFX runtime preview" },
        @{ Script = "RenderArtStressCombatPreview.gd"; Marker = "RENDER PASS: Art stress combat runtime preview" }
    )
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($gate in $gates) {
        $output = (& $godot --path . --quit-after 180 --script "res://scripts/art/$($gate.Script)" 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
        $markerCount = ([regex]::Matches($output, [regex]::Escape($gate.Marker))).Count
        if ($exitCode -ne 0) {
            $failures.Add("$($gate.Script): exited with $exitCode")
        }
        if ($markerCount -ne 1) {
            $failures.Add("$($gate.Script): expected one pass marker, found $markerCount")
        }
        if ($output -match $forbidden) {
            $failures.Add("$($gate.Script): output contained an error or leak marker")
        }
        if ($failures | Where-Object { $_ -like "$($gate.Script):*" }) {
            Write-Host "===== $($gate.Script) FAILED =====" -ForegroundColor Red
            Write-Host $output
        } else {
            Write-Host "ART RENDER PASS: $($gate.Script)" -ForegroundColor Green
        }
    }

    if ($failures.Count -gt 0) {
        Write-Host "`nART RENDER RUN FAILED ($($failures.Count) violations)" -ForegroundColor Red
        $failures | ForEach-Object { Write-Host "- $_" }
        exit 1
    }

    Write-Host "`nART RENDER RUN PASS: $($gates.Count) gates" -ForegroundColor Green
} finally {
    Pop-Location
}
