Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ToolPath {
    param(
        [string[]]$EnvVarNames,
        [string[]]$CommandNames,
        [string[]]$CandidatePaths,
        [string]$DisplayName
    )

    foreach ($envVarName in $EnvVarNames) {
        $requested = [Environment]::GetEnvironmentVariable($envVarName)
        if ([string]::IsNullOrWhiteSpace($requested)) {
            continue
        }

        if (Test-Path -LiteralPath $requested) {
            return (Resolve-Path -LiteralPath $requested).Path
        }

        $resolvedCommand = Get-Command $requested -ErrorAction SilentlyContinue
        if ($resolvedCommand) {
            return $resolvedCommand.Source
        }

        throw "Unable to resolve $DisplayName from environment variable $envVarName='$requested'."
    }

    foreach ($commandName in $CommandNames) {
        $resolvedCommand = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($resolvedCommand) {
            return $resolvedCommand.Source
        }
    }

    foreach ($candidatePath in $CandidatePaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return (Resolve-Path -LiteralPath $candidatePath).Path
        }
    }

    throw "Unable to find $DisplayName. Set one of the environment variables [$($EnvVarNames -join ', ')] or install it in a standard location."
}

# PowerShell script to build patches.elf
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CC = Resolve-ToolPath `
    -EnvVarNames @("MM64_PATCHES_CC", "PATCHES_C_COMPILER") `
    -CommandNames @("clang", "clang.exe") `
    -CandidatePaths @(
        "C:\Program Files\LLVM\bin\clang.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin\clang.exe",
        "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin\clang.exe"
    ) `
    -DisplayName "clang"
$LD = Resolve-ToolPath `
    -EnvVarNames @("MM64_PATCHES_LD", "PATCHES_LD") `
    -CommandNames @("ld.lld", "ld.lld.exe", "lld-link", "lld-link.exe") `
    -CandidatePaths @(
        "C:\Program Files\LLVM\bin\ld.lld.exe",
        "C:\Program Files\LLVM\bin\lld-link.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin\ld.lld.exe",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\Llvm\x64\bin\lld-link.exe",
        "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin\ld.lld.exe",
        "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin\lld-link.exe"
    ) `
    -DisplayName "ld.lld"

$CFLAGS = @(
    "-target", "mips",
    "-mips2",
    "-mabi=32",
    "-O2",
    "-G0",
    "-mno-abicalls",
    "-mno-odd-spreg",
    "-fomit-frame-pointer",
    "-ffast-math",
    "-fno-unsafe-math-optimizations",
    "-fno-builtin-memset",
    "-Wall",
    "-Wextra",
    "-Wno-incompatible-library-redeclaration",
    "-Wno-unused-parameter",
    "-Wno-unknown-pragmas",
    "-Wno-unused-variable",
    "-Wno-missing-braces",
    "-Wno-unsupported-floating-point-opt"
)

$CPPFLAGS = @(
    "-nostdinc",
    "-D_LANGUAGE_C",
    "-DMIPS",
    "-I", "dummy_headers",
    "-I", "libultra",
    "-I", "../lib/rt64/include"
)

$LDFLAGS = @(
    "-nostdlib",
    "-T", "patches.ld",
    "-T", "syms.ld",
    "-Map", "patches.map",
    "--unresolved-symbols=ignore-all",
    "--emit-relocs"
)

Push-Location $ScriptDir

Write-Host "Using clang: $CC"
Write-Host "Using linker: $LD"
Write-Host "Compiling print.c..."
& $CC @CFLAGS @CPPFLAGS "print.c" "-MMD" "-MF" "print.d" "-c" "-o" "print.o"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to compile print.c. Ensure clang supports the MIPS target used by patch overlays."
    Pop-Location
    exit 1
}

Write-Host "Linking patches.elf..."
& $LD "print.o" @LDFLAGS "-o" "patches.elf"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to link patches.elf"
    Pop-Location
    exit 1
}

Write-Host "Build successful!"
Pop-Location
