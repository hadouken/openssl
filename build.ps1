# This script will download and build OpenSSL in both debug and release
# configurations.

$PACKAGES_DIRECTORY = Join-Path $PSScriptRoot "packages"
$OUTPUT_DIRECTORY   = Join-Path $PSScriptRoot "bin"
$VERSION            = "0.0.0"

if (Test-Path Env:\APPVEYOR_BUILD_VERSION) {
    $VERSION = $env:APPVEYOR_BUILD_VERSION
}

# 7zip configuration section
$7ZIP_VERSION      = "9.20"
$7ZIP_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "7zip-$7ZIP_VERSION"
$7ZIP_TOOL         = Join-Path $7ZIP_DIRECTORY "7za.exe"
$7ZIP_PACKAGE_FILE = "7za$($7ZIP_VERSION.replace('.', '')).zip"
$7ZIP_DOWNLOAD_URL = "http://downloads.sourceforge.net/project/sevenzip/7-Zip/$7ZIP_VERSION/$7ZIP_PACKAGE_FILE"

# NASM configuration section
$NASM_VERSION      = "2.11.06"
$NASM_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "nasm-$NASM_VERSION"
$NASM_PACKAGE_FILE = "nasm-$NASM_VERSION-win32.zip"
$NASM_DOWNLOAD_URL = "http://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/win32/$NASM_PACKAGE_FILE"

# Strawberry Perl configuration section
$PERL_VERSION      = "5.20.1.1"
$PERL_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "strawberry-perl-$PERL_VERSION"
$PERL_PACKAGE_FILE = "strawberry-perl-$PERL_VERSION-32bit-portable.zip"
$PERL_DOWNLOAD_URL = "http://strawberryperl.com/download/5.20.1.1/$PERL_PACKAGE_FILE"

# OpenSSL configuration section
$OPENSSL_VERSION      = "1.0.2"
$OPENSSL_DIRECTORY    = Join-Path $PACKAGES_DIRECTORY "openssl-$OPENSSL_VERSION"
$OPENSSL_PACKAGE_FILE = "openssl-$OPENSSL_VERSION.tar.gz"
$OPENSSL_DOWNLOAD_URL = "https://www.openssl.org/source/$OPENSSL_PACKAGE_FILE"

# Nuget configuration section
$NUGET_FILE         = "nuget.exe"
$NUGET_TOOL         = Join-Path $PACKAGES_DIRECTORY $NUGET_FILE
$NUGET_DOWNLOAD_URL = "https://nuget.org/$NUGET_FILE"

function Download-File {
    param (
        [string]$url,
        [string]$target
    )

    $webClient = new-object System.Net.WebClient
    $webClient.DownloadFile($url, $target)
}

function Extract-File {
    param (
        [string]$file,
        [string]$target
    )

    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $target)
}

function Load-DevelopmentTools {
    # Set environment variables for Visual Studio Command Prompt
    
    pushd "c:\Program Files (x86)\Microsoft Visual Studio 12.0\VC"
    
    cmd /c "vcvarsall.bat&set" |
    foreach {
        if ($_ -match "=") {
            $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
        }
    }
    
    popd
}

# Get our dev tools
Load-DevelopmentTools

# Create packages directory if it does not exist
if (!(Test-Path $PACKAGES_DIRECTORY)) {
    New-Item -ItemType Directory -Path $PACKAGES_DIRECTORY | Out-Null
}

# Download 7zip
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $7ZIP_PACKAGE_FILE))) {
    Write-Host "Downloading $7ZIP_PACKAGE_FILE"
    Download-File $7ZIP_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $7ZIP_PACKAGE_FILE)
}

# Download NASM
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $NASM_PACKAGE_FILE))) {
    Write-Host "Downloading $NASM_PACKAGE_FILE"
    Download-File $NASM_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $NASM_PACKAGE_FILE)
}

# Download Strawberry-Perl
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $PERL_PACKAGE_FILE))) {
    Write-Host "Downloading $PERL_PACKAGE_FILE"
    Download-File $PERL_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $PERL_PACKAGE_FILE)
}

# Download OpenSSL
if (!(Test-Path (Join-Path $PACKAGES_DIRECTORY $OPENSSL_PACKAGE_FILE))) {
    Write-Host "Downloading $OPENSSL_PACKAGE_FILE"
    Download-File $OPENSSL_DOWNLOAD_URL (Join-Path $PACKAGES_DIRECTORY $OPENSSL_PACKAGE_FILE)
}

# Download Nuget
if (!(Test-Path $NUGET_TOOL)) {
    Write-Host "Downloading $NUGET_FILE"
    Download-File $NUGET_DOWNLOAD_URL $NUGET_TOOL
}

# Unpack 7zip
if (!(Test-Path $7ZIP_DIRECTORY)) {
    Write-Host "Unpacking $7ZIP_PACKAGE_FILE"
    Extract-File (Join-Path $PACKAGES_DIRECTORY $7ZIP_PACKAGE_FILE) $7ZIP_DIRECTORY
}

# Unpack NASM
if (!(Test-Path $NASM_DIRECTORY)) {
    Write-Host "Unpacking $NASM_PACKAGE_FILE"
    Extract-File (Join-Path $PACKAGES_DIRECTORY $NASM_PACKAGE_FILE) $PACKAGES_DIRECTORY
}

# Unpack Strawberry-Perl
if (!(Test-Path $PERL_DIRECTORY)) {
    Write-Host "Unpacking $PERL_PACKAGE_FILE"
    Extract-File (Join-Path $PACKAGES_DIRECTORY $PERL_PACKAGE_FILE) $PERL_DIRECTORY
}

# Unpack OpenSSL
if (!(Test-Path $OPENSSL_DIRECTORY)) {
    Write-Host "Unpacking $OPENSSL_PACKAGE_FILE"
    $tmp = Join-Path $PACKAGES_DIRECTORY $OPENSSL_PACKAGE_FILE

    & "$7ZIP_TOOL" x $tmp -o"$PACKAGES_DIRECTORY"
    & "$7ZIP_TOOL" x $tmp.replace('.gz', '') -o"$PACKAGES_DIRECTORY"
}

function Compile-OpenSSL {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $OPENSSL_DIRECTORY

    # Set up portable Strawberry Perl
    $env:Path = "$(Join-Path $PERL_DIRECTORY perl\site\bin);" + $env:Path
    $env:Path = "$(Join-Path $PERL_DIRECTORY perl\bin);" + $env:Path
    $env:Path = "$(Join-Path $PERL_DIRECTORY c\bin);" + $env:Path

    # Set up nasm
    $env:Path = "$NASM_DIRECTORY;" + $env:Path

    # Configure
    $target = "<invalid>"

    if ($configuration -eq "debug") {
        $target = "debug-VC-WIN32"
    } else {
        $target = "VC-WIN32"
    }

    perl Configure $target --prefix="bin/$platform/$configuration"
    
    # Run nasm
    cmd /c ms\do_nasm.bat

    # Run nmake
    nmake -f ms\ntdll.mak

    # Run nmake install
    nmake -f ms\ntdll.mak install

    popd
}

function Output-OpenSSL {
    param (
        [string]$platform,
        [string]$configuration
    )

    pushd $OPENSSL_DIRECTORY
    
    $t = Join-Path $OUTPUT_DIRECTORY "$platform/$configuration"

    # Copy output files
    xcopy /y bin\$platform\$configuration\bin\*.dll "$t\bin\*"
    xcopy /y bin\$platform\$configuration\lib\*.lib "$t\lib\*"
    xcopy /y bin\$platform\$configuration\include\* "$t\include\*" /E

    popd
}

Compile-OpenSSL "win32" "debug"
Output-OpenSSL  "win32" "debug"

Compile-OpenSSL "win32" "release"
Output-OpenSSL  "win32" "release"

# Package with NuGet

copy hadouken.openssl.nuspec $OUTPUT_DIRECTORY

pushd $OUTPUT_DIRECTORY
Start-Process "$NUGET_TOOL" -ArgumentList "pack hadouken.openssl.nuspec -Properties version=$VERSION" -Wait -NoNewWindow
popd
