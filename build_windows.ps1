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

function Test-RequiredSubmodulesReady {
    param([string]$RepoRoot)

    $requiredSubmodules = @(
        @{ Path = "lib/rt64"; Sentinel = "CMakeLists.txt" },
        @{ Path = "lib/lunasvg"; Sentinel = "CMakeLists.txt" },
        @{ Path = "lib/RmlUi"; Sentinel = "CMakeLists.txt" },
        @{ Path = "lib/N64ModernRuntime"; Sentinel = "CMakeLists.txt" },
        @{ Path = "lib/freetype-windows-binaries"; Sentinel = "include/ft2build.h" },
        @{ Path = "MegaMan64RecompSyms"; Sentinel = "README.md" }
    )

    $missing = @()
    foreach ($submodule in $requiredSubmodules) {
        $candidate = Join-Path (Join-Path $RepoRoot $submodule.Path) $submodule.Sentinel
        if (-not (Test-Path -LiteralPath $candidate)) {
            $missing += $submodule.Path
        }
    }

    if ($missing.Count -eq 0) {
        return
    }

    $messageLines = @(
        "Required git submodules are missing or not initialized:",
        ""
    )

    foreach ($path in $missing) {
        $messageLines += "  - $path"
    }

    $messageLines += ""
    $messageLines += "Run this once from the repository root, then try again:"
    $messageLines += "  git submodule update --init --recursive"

    throw ($messageLines -join [Environment]::NewLine)
}

function Get-RecompilerToolPath {
    param(
        [string]$RepoRoot,
        [string]$BaseName
    )

    foreach ($candidate in @(
        (Join-Path $RepoRoot "build-tools\$BaseName"),
        (Join-Path $RepoRoot $BaseName)
    )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return ""
}

function Test-GeneratedSourcesReady {
    param([string]$RepoRoot)

    $rspOutput = Join-Path $RepoRoot "rsp\aspMain.cpp"
    $recompiledFuncsDir = Join-Path $RepoRoot "RecompiledFuncs"
    $hasRspOutput = Test-Path -LiteralPath $rspOutput
    $hasFunctionOutputs = $false

    if (Test-Path -LiteralPath $recompiledFuncsDir) {
        $generatedSources = Get-ChildItem -LiteralPath $recompiledFuncsDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in ".c", ".cpp" }
        $hasFunctionOutputs = $generatedSources.Count -gt 0
    }

    if ($hasRspOutput -and $hasFunctionOutputs) {
        return
    }

    $n64recompPath = Get-RecompilerToolPath -RepoRoot $RepoRoot -BaseName "N64Recomp.exe"
    $rspRecompPath = Get-RecompilerToolPath -RepoRoot $RepoRoot -BaseName "RSPRecomp.exe"
    $romPath = Join-Path $RepoRoot "megaman64.us.z64"

    $messageLines = @(
        "Required generated recompiler sources are missing:",
        ""
    )

    if (-not $hasRspOutput) {
        $messageLines += "  - rsp\aspMain.cpp"
    }
    if (-not $hasFunctionOutputs) {
        $messageLines += "  - RecompiledFuncs\*.c / RecompiledFuncs\*.cpp"
    }

    $messageLines += ""
    if (-not (Test-Path -LiteralPath $romPath)) {
        $messageLines += "The expected ROM was not found at:"
        $messageLines += "  $romPath"
        $messageLines += ""
    }

    if ([string]::IsNullOrWhiteSpace($n64recompPath) -or [string]::IsNullOrWhiteSpace($rspRecompPath)) {
        $messageLines += "Build or copy these tools into the repo root (or build-tools) first:"
        if ([string]::IsNullOrWhiteSpace($n64recompPath)) {
            $messageLines += "  - N64Recomp.exe"
        }
        if ([string]::IsNullOrWhiteSpace($rspRecompPath)) {
            $messageLines += "  - RSPRecomp.exe"
        }
        $messageLines += ""
    }

    $messageLines += "Then generate the sources from the repository root:"
    $messageLines += "  .\N64Recomp.exe us.rev1.toml"
    $messageLines += "  .\RSPRecomp.exe asp.toml"
    $messageLines += ""
    $messageLines += "See BUILDING.md for the full setup flow."

    throw ($messageLines -join [Environment]::NewLine)
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
Test-RequiredSubmodulesReady -RepoRoot $repoRoot
Test-GeneratedSourcesReady -RepoRoot $repoRoot
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
