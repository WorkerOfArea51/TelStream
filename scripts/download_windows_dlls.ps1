
# PowerShell script to download TDLib Windows DLLs for local development
# CI uses inline PowerShell — this script is for LOCAL SETUP only

$baseUrl = "https://raw.githubusercontent.com/WorkerOfArea51/TelStream/native-libs-win/windows/runner/libs"
$libsDir = Join-Path $PSScriptRoot "..\windows\runner\libs"

if (-Not (Test-Path -Path $libsDir)) {
    New-Item -ItemType Directory -Force -Path $libsDir | Out-Null
}

$dlls = @(
    "tdjson.dll",
    "libcrypto-1_1-x64.dll",
    "libssl-1_1-x64.dll",
    "msvcp140.dll",
    "zlib1.dll"
)

foreach ($dll in $dlls) {
    $target = Join-Path -Path $libsDir -ChildPath $dll
    if (-Not (Test-Path -Path $target)) {
        Write-Host "Downloading $dll..."
        Invoke-WebRequest -Uri "$baseUrl/$dll" -OutFile $target
    } else {
        Write-Host "$dll already exists, skipping."
    }
}

Write-Host "Done! All DLLs are in $libsDir"
