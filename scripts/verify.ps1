#Requires -Version 5.1
# Karkain-Validation verification gate using the real Karkain v1.2.0 toolchain.
param(
    [string]$KarkainSource = 'C:\Windows\Temp\opencode\Karkain-v1.2.0',
    [string]$KarkainExe    = 'C:\Windows\Temp\opencode\karkain-bin\karkain-v1.2.0-windows-amd64\karkain.exe',
    [string]$CcDir          = 'C:\msys64\ucrt64\bin'
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $KarkainSource)) { throw "Karkain source not found: $KarkainSource" }
if (-not (Test-Path -LiteralPath $KarkainExe)) { throw "Karkain executable not found: $KarkainExe" }
if (Test-Path -LiteralPath $CcDir) { $env:PATH = "$CcDir;$env:PATH" }

$enc = New-Object System.Text.UTF8Encoding($false)
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('kval-verify-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

function Invoke-Karkain {
    param([string[]]$CmdArgs)
    Push-Location $KarkainSource
    try {
        & $KarkainExe @CmdArgs 2>&1 |
            Where-Object { $_ -notmatch 'undefined reference|collect2|ld returned 1 exit status' } |
            Out-String
    } finally { Pop-Location }
}

try {
    $module = Join-Path $repo 'src\validation.kark'

    $out = Invoke-Karkain @('check', $module)
    $code = $LASTEXITCODE
    Write-Output "CHECK module: exit=$code"
    if ($code -ne 0) { Write-Output $out; throw 'module check failed' }

    $tests = Join-Path $repo 'tests\api_tests.kark'
    $combined = Join-Path $tmp 'kval_suite_test.kark'
    [System.IO.File]::WriteAllText($combined, (Get-Content -LiteralPath $module -Raw) + "`n" + (Get-Content -LiteralPath $tests -Raw), $enc)
    $out = Invoke-Karkain @('test', $combined)
    $code = $LASTEXITCODE
    Write-Output "TEST native: exit=$code"
    Write-Output $out
    if ($code -ne 0) { throw 'native tests failed' }
    if ($out -notlike '*26 tests, 26 passed, 0 failed*') { throw 'native test summary mismatch' }

    $verify = Join-Path $repo 'src\verify.kark'
    $out = Invoke-Karkain @('run', $verify)
    $code = $LASTEXITCODE
    Write-Output "RUN integration: exit=$code"
    Write-Output $out
    if ($code -ne 0) { throw 'integration failed' }
    if ($out -notlike '*profile: 4 validation error(s)*') { throw 'integration report missing' }

    $neg = Join-Path $tmp 'negative_test.kark'
    [System.IO.File]::WriteAllText($neg, "func test_expected_failure() {`n    assert(false)`n}`n", $enc)
    $null = Invoke-Karkain @('test', $neg)
    $code = $LASTEXITCODE
    Write-Output "TEST negative-gate: exit=$code (expected 4)"
    if ($code -ne 4) { throw 'negative gate failed' }

    $exDir = Join-Path $tmp 'example'
    New-Item -ItemType Directory -Path $exDir | Out-Null
    Copy-Item -LiteralPath $module -Destination (Join-Path $exDir 'validation.kark')
    Copy-Item -LiteralPath (Join-Path $repo 'examples\user_profile.kark') -Destination (Join-Path $exDir 'user_profile.kark')
    $out = Invoke-Karkain @('run', (Join-Path $exDir 'user_profile.kark'))
    $code = $LASTEXITCODE
    Write-Output "RUN example: exit=$code"
    Write-Output $out
    if ($code -ne 0) { throw 'example failed' }
    if ($out -notlike '*user profile: 0 validation error(s)*') { throw 'example summary missing' }
    if ($out -notlike '*valid=*') { throw 'example status missing' }

    Write-Output 'VERIFY: ALL GATES PASSED'
}
finally {
    try { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
