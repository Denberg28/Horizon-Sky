param([Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path $PackageDirectory).Path
$info = Get-Content (Join-Path $package BUILD_INFO.json) | ConvertFrom-Json
$expected = Get-Content (Join-Path $package FILE_SHA256.json) | ConvertFrom-Json
foreach ($name in 'HorizonSky.exe','HorizonSky.pck') {
    if ((Get-FileHash (Join-Path $package $name) -Algorithm SHA256).Hash.ToLower() -ne $expected.$name) { throw "Hash mismatch: $name" }
}
$report = [ordered]@{
    timestamp = (Get-Date).ToString('o'); source = $info.commit; version = $info.version
    windows = [Environment]::OSVersion.VersionString
    radio = (Read-Host 'Radio model, firmware, USB mode and cable')
    pc = (Read-Host 'CPU, GPU, RAM, display and driver')
    checks = @()
}
Start-Process (Join-Path $package HorizonSky.exe) -WorkingDirectory $package
$procedures = @(
    'Select radio. Map unique axes; sweep/capture centered controls. Confirm min/max, reversals, center drift <=0.04; each centered output reaches +/-0.98 and throttle <=0.02 / >=0.98.',
    'Confirm high throttle or noncentered roll/pitch/yaw blocks launch; lower/center then launch. Move each physical channel and verify only intended virtual control.',
    'During bank, unplug radio. Measure loss-to-frozen-screen <=100 ms using >=120 fps video. Verify time/position frozen, keyboard cannot take over; reconnect stays paused until centered/low-throttle explicit resume.',
    'Repeat unplug/reconnect/resume 20 times. If ID changes, use hangar and explicit reselection. A second joystick must never take authority automatically.',
    'Alt-Tab during input. Measure focus-loss-to-freeze <=100 ms. Return stays paused. Center/lower and explicitly resume. Repeat 5 times.',
    'On each planet at 1280x800, verify menu/controller controls fit and HUD/gates are readable. Fly with keyboard and radio, pass/miss gates, hit terrain, read debrief and replay.',
    'Record a debrief, exit/restart. Confirm best/attempt/last-result persistence. With game closed, back up saves; corrupt main JSON and confirm backup recovery. Restore originals afterward.',
    'Run for 10 minutes at 1280x800; measure sustained >=60 fps and p95 input-to-display <=50 ms with >=120 fps capture. Record measurement method and values.',
    'Close game while controller connected; restart safely in hangar. Extract candidate to a clean folder and launch; retain previous package and confirm rollback with backed-up saves.',
    'Training observation: five initial runs and five later runs on same course/craft. Record median gates/precision, contact count, practice interval; do not equate this with real-flight proficiency.'
)
foreach ($procedure in $procedures) {
    Write-Host "`n$procedure"
    do { $status = (Read-Host 'Observed result: PASS / FAIL / NOT TESTED / BLOCKED').ToUpper() } until ($status -in @('PASS','FAIL','NOT TESTED','BLOCKED'))
    $evidence = Read-Host 'Actual observations, timing values/method, and evidence file path'
    $report.checks += [ordered]@{ procedure=$procedure; status=$status; evidence=$evidence }
}
$destination = Join-Path $package ('HIL-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
$report | ConvertTo-Json -Depth 8 | Set-Content $destination -Encoding utf8
Write-Host "Saved local report: $destination. Any FAIL/BLOCKED/NOT TESTED required check prevents stable promotion."
