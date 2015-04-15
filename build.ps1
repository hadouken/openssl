# This script will download and build OpenSSL in debug, release
# or both configurations for Win32 or x64.
#
# Requires PowerShell version 3.0 or newer
#
# Usage:
# ------
# build.ps1 [-vs_version 120 | 110 | 100 | 90]
#           [-config     release | debug | both]
#           [-platform   Win32 | x64]
#

[CmdletBinding()]
Param
(
  [Parameter()]
  [ValidateSet(90, 100, 110, 120)]
  [int] $vs_version = 110,

  [Parameter()]
  [ValidateSet('release', 'debug', 'both')]
  [string] $config = 'release',

  [Parameter()]
  [ValidateSet('Win32', 'x64')]
  [string] $platform = 'x64'
)


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
$OPENSSL_VERSION      = "1.0.2a"
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
    
    if ($vs_version -eq 0)
    {
      if     ($Env:VS120COMNTOOLS -ne '') { $script:vs_version = 120 }
      elseif ($Env:VS110COMNTOOLS -ne '') { $script:vs_version = 110 }
      elseif ($Env:VS100COMNTOOLS -ne '') { $script:vs_version = 100 }
      elseif ($Env:VS90COMNTOOLS  -ne '') { $script:vs_version = 90 }
      else
      {
        Write-Host 'Visual Studio not found, exiting.'
        Exit
      }
    }

    $vsct = "VS$($vs_version)COMNTOOLS"
    $vsdir = (Get-Item Env:$vsct).Value
    $Command = ''
    if ($platform -eq 'x64')
    {
      $Command = "$($vsdir)..\..\VC\bin\x86_amd64\vcvarsx86_amd64.bat"
    }
    else
    {
      $Command = "$($vsdir)vsvars32.bat"
    }

    $tempFile = [IO.Path]::GetTempFileName()
    cmd /c " `"$Command`" && set > `"$tempFile`" "
    Get-Content $tempFile | Foreach-Object {
      if($_ -match "^(.*?)=(.*)$")
      {
        Set-Content "Env:$($matches[1])" $matches[2]
      }
    }
    Remove-Item $tempFile
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

function Unpack-OpenSSL {
  # Unpack OpenSSL
    if (!(Test-Path $OPENSSL_DIRECTORY)) {
        Write-Host "Unpacking $OPENSSL_PACKAGE_FILE"
        $tmp = Join-Path $PACKAGES_DIRECTORY $OPENSSL_PACKAGE_FILE

        & "$7ZIP_TOOL" x $tmp -o"$PACKAGES_DIRECTORY" -y
        & "$7ZIP_TOOL" x $tmp.replace('.gz', '') -o"$PACKAGES_DIRECTORY" -y
    }
}

function Compile-OpenSSL {
    param (
        [string]$winplatform,
        [string]$configuration,
        [string]$target
    )

    pushd $OPENSSL_DIRECTORY

    # Set up portable Strawberry Perl
    $env:Path = "$(Join-Path $PERL_DIRECTORY perl\site\bin);" + $env:Path
    $env:Path = "$(Join-Path $PERL_DIRECTORY perl\bin);" + $env:Path
    $env:Path = "$(Join-Path $PERL_DIRECTORY c\bin);" + $env:Path

    # Set up nasm
    $env:Path = "$NASM_DIRECTORY;" + $env:Path

    perl Configure $target --prefix="bin/$winplatform/$configuration"
    
    # Run nasm
    cmd /c ms\do_nasm.bat

    if ($winplatform -eq "win64") {
        cmd /c ms\do_win64a
    }

    # Run nmake
    nmake -f ms\ntdll.mak

    # Run nmake install
    nmake -f ms\ntdll.mak install

    popd
}

function Output-OpenSSL {
    param (
        [string]$winplatform,
        [string]$configuration
    )

    pushd $OPENSSL_DIRECTORY
    
    $t = Join-Path $OUTPUT_DIRECTORY "$winplatform"

    # Copy output files
    xcopy /y bin\$winplatform\$configuration\bin\*.dll "$t\bin\$configuration\*"
    xcopy /y bin\$winplatform\$configuration\lib\*.lib "$t\lib\$configuration\*"
    xcopy /y bin\$winplatform\$configuration\include\* "$t\include\*" /E

    $d = ""
    $b = "32"

    if ($configuration -eq "debug") { $d = "d" }
    if ($winplatform -eq "win64") { $b = "64" }

    Rename-Item -path "$t\bin\$configuration\libeay32.dll" -newname "libeay$b$d.dll"
    Rename-Item -path "$t\bin\$configuration\ssleay32.dll" -newname "ssleay$b$d.dll"

    popd
}



if ($platform -eq "Win32") {
    if (Test-Path $OPENSSL_DIRECTORY) {
        Remove-Item -Recurse -Force $OPENSSL_DIRECTORY
    }

    Unpack-OpenSSL

    if ($config -eq "debug" -or ($config -eq "both")) {
        Compile-OpenSSL "win32" "debug" "debug-VC-WIN32"
        Output-OpenSSL  "win32" "debug"
    }

    if ($config -eq "release" -or ($config -eq "both")) {
        Compile-OpenSSL "win32" "release" "VC-WIN32"
        Output-OpenSSL  "win32" "release"
    }
}
elseif ($platform -eq "x64") {
    if (Test-Path $OPENSSL_DIRECTORY) {
        Remove-Item -Recurse -Force $OPENSSL_DIRECTORY
    }

    Unpack-OpenSSL

    if ($config -eq "debug" -or ($config -eq "both")) {
        Compile-OpenSSL "win64" "debug" "debug-VC-WIN64A"
        Output-OpenSSL  "win64" "debug"
    }

    if ($config -eq "release" -or ($config -eq "both")) {
        Compile-OpenSSL "win64" "release" "VC-WIN64A"
        Output-OpenSSL  "win64" "release"
    }
}
else {
    Write-Error "Unknown platform: $platform"
    Exit
}

# Package with NuGet

$p = "32"
if ($platform -eq "x64") { $p = "64" }
copy "hadouken$p.openssl.nuspec" $OUTPUT_DIRECTORY

pushd $OUTPUT_DIRECTORY
Start-Process "$NUGET_TOOL" -ArgumentList "pack hadouken$p.openssl.nuspec -Properties version=$VERSION" -Wait -NoNewWindow
popd
