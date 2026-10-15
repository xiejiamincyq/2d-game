param([string]$ProjectRoot=(Join-Path $PSScriptRoot '../..'))
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\','/')
$taskScripts=Join-Path $taskRoot 'scripts'
if(-not (Test-Path -LiteralPath $taskScripts -PathType Container)) { Write-Output 'PAUSE OWNERSHIP FAIL: scripts root missing'; exit 1 }
$taskOwners=@('scripts/Main.gd','scripts/campaign/ChapterRun.gd')
$taskFailures=@()
$taskCount=0
foreach($file in Get-ChildItem -LiteralPath $taskScripts -Recurse -File -Filter '*.gd') {
    $relative=$file.FullName.Substring($taskRoot.Length+1).Replace('\','/')
    # Author/legacy fixtures are not shipped. No other campaign/UI/actor gets
    # an implicit exemption merely because it lives beside an allowed owner.
    if($relative.StartsWith('scripts/tests/') -or $relative.StartsWith('scripts/art/')) { continue }
    $taskCount++
    $lineNumber=0
    foreach($line in Get-Content -LiteralPath $file.FullName -Encoding utf8) {
        $lineNumber++
        $code=$line -replace '"(?:\\.|[^"\\])*"|''(?:\\.|[^''\\])*''','""'
        $code=$code -replace '#.*$',''
        if($code -match 'get_tree\(\)\.paused\s*=(?!=)' -and $relative -notin $taskOwners) {
            $taskFailures+=($relative+':'+$lineNumber+' unauthorized SceneTree.paused writer')
        }
    }
}
if($taskCount -eq 0) { $taskFailures+='no production GDScript sources found' }
if($taskFailures.Count) {
    foreach($finding in $taskFailures) { Write-Output ('PAUSE OWNERSHIP FAIL: '+$finding) }
    exit 1
}
Write-Output ('CHECK PASS: SceneTree.paused ownership ('+$taskCount+' production scripts, two explicit owners)')
exit 0
