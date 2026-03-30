[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release", "RelWithDebInfo", "MinSizeRel")]
    [string]$Configuration = "Debug",
    [string]$BuildDir = "build-msvc",
    [ValidateSet("auto", "msvc", "clang-cl")]
    [string]$Toolchain = "auto",
    [string]$Target = "MegaMan64Recompiled",
    [string]$Sdl2Root = "",
    [switch]$NoFetchSdl2,
    [switch]$SkipConfigure,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Quote-CmdArg {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }

    $escaped = $Value -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Get-VisualStudioInstallationPath {
    $vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere)) {
        throw "vswhere.exe was not found at '$vswhere'. Install Visual Studio 2022 with Desktop development with C++."
    }

    $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($installationPath)) {
        throw "Unable to locate a Visual Studio installation with MSVC tools."
    }

    return $installationPath.Trim()
}

function Resolve-Toolchain {
    param(
        [string]$RequestedToolchain,
        [string]$VisualStudioRoot
    )

    $vsClangCandidate = Join-Path $VisualStudioRoot "VC\Tools\Llvm\x64\bin\clang-cl.exe"

    if ($RequestedToolchain -eq "clang-cl") {
        $clangCandidates = @(
            $vsClangCandidate,
            "C:\Program Files\LLVM\bin\clang-cl.exe"
        )

        foreach ($candidate in $clangCandidates) {
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }

        throw "clang-cl was requested but was not found. Install the Visual Studio LLVM toolchain or LLVM for Windows."
    }

    if ($RequestedToolchain -eq "auto" -and (Test-Path -LiteralPath $vsClangCandidate)) {
        return (Resolve-Path -LiteralPath $vsClangCandidate).Path
    }

    $msvcRoots = Get-ChildItem (Join-Path $VisualStudioRoot "VC\Tools\MSVC") -Directory | Sort-Object Name -Descending
    foreach ($msvcRoot in $msvcRoots) {
        $candidate = Join-Path $msvcRoot.FullName "bin\Hostx64\x64\cl.exe"
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Unable to find cl.exe under '$VisualStudioRoot'."
}

function Resolve-LlvmBinDirectory {
    param([string]$VisualStudioRoot)

    $llvmBinCandidates = @(
        (Join-Path $VisualStudioRoot "VC\Tools\Llvm\x64\bin"),
        "C:\Program Files\LLVM\bin"
    )

    foreach ($candidate in $llvmBinCandidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate "clang.exe")) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return ""
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$visualStudioRoot = Get-VisualStudioInstallationPath
$vsDevCmd = Join-Path $visualStudioRoot "Common7\Tools\VsDevCmd.bat"
if (-not (Test-Path -LiteralPath $vsDevCmd)) {
    throw "VsDevCmd.bat was not found under '$visualStudioRoot'."
}

$resolvedToolchain = Resolve-Toolchain -RequestedToolchain $Toolchain -VisualStudioRoot $visualStudioRoot
$llvmBinDir = Resolve-LlvmBinDirectory -VisualStudioRoot $visualStudioRoot
$buildPath = Join-Path $repoRoot $BuildDir

$configureArgs = @(
    "-S", $repoRoot,
    "-B", $buildPath,
    "-G", "Ninja",
    "-DCMAKE_BUILD_TYPE=$Configuration",
    "-DCMAKE_C_COMPILER=$resolvedToolchain",
    "-DCMAKE_CXX_COMPILER=$resolvedToolchain"
)

if (-not [string]::IsNullOrWhiteSpace($Sdl2Root)) {
    $configureArgs += "-DMM64_WINDOWS_SDL2_ROOT=$Sdl2Root"
    $configureArgs += "-DMM64_WINDOWS_FETCH_SDL2=OFF"
}
elseif ($NoFetchSdl2) {
    $configureArgs += "-DMM64_WINDOWS_FETCH_SDL2=OFF"
}

$buildArgs = @(
    "--build", $buildPath,
    "--config", $Configuration
)

if (-not [string]::IsNullOrWhiteSpace($Target)) {
    $buildArgs += "--target"
    $buildArgs += $Target
}

$cmdSegments = @(
    'call ' + (Quote-CmdArg $vsDevCmd) + ' -arch=x64 -host_arch=x64'
)

if (-not [string]::IsNullOrWhiteSpace($llvmBinDir)) {
    $cmdSegments += 'set "PATH=' + $llvmBinDir + ';%PATH%"'
}

if (-not $SkipConfigure) {
    $cmdSegments += 'cmake ' + (($configureArgs | ForEach-Object { Quote-CmdArg $_ }) -join ' ')
}

if (-not $SkipBuild) {
    $cmdSegments += 'cmake ' + (($buildArgs | ForEach-Object { Quote-CmdArg $_ }) -join ' ')
}

$cmdLine = $cmdSegments -join ' && '

Write-Host "Visual Studio: $visualStudioRoot"
Write-Host "Toolchain: $resolvedToolchain"
if (-not [string]::IsNullOrWhiteSpace($llvmBinDir)) {
    Write-Host "LLVM bin: $llvmBinDir"
}
Write-Host "Build directory: $buildPath"

& cmd.exe /d /c $cmdLine
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
