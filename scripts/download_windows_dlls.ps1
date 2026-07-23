# PowerShell script to download TDLib Windows DLLs
# Since these are untracked by Git, run this script when setting up the repository on a new machine.

$url_base = "https://example.com/tdlib_binaries/windows-x64/"
$libs_dir = "..\windows\runner\libs"

if (-Not (Test-Path -Path $libs_dir)) {
    New-Item -ItemType Directory -Force -Path $libs_dir
}

$dlls = @(
    "libcrypto-1_1-x64-53936b87b820e80288ef1254b4e551b8.dll",
    "libssl-1_1-x64-dc1629b6d9c815c1d6e7b7c2493d481e.dll",
    "msvcp140-a4c2229bdc2a2a630acdc095b4d86008.dll",
    "tdjson.dll",
    "zlib1-93e9243a44c29200eeacaf9658efe255.dll"
)

foreach ($dll in $dlls) {
    $target_file = Join-Path -Path $libs_dir -ChildPath $dll
    if (-Not (Test-Path -Path $target_file)) {
        Write-Host "Downloading $dll..."
        # Uncomment and configure your private URL or GitHub release URL here
        # Invoke-WebRequest -Uri "$url_base$dll" -OutFile $target_file
        Write-Host "Please download $dll manually or configure the URL in this script."
    } else {
        Write-Host "$dll already exists."
    }
}
