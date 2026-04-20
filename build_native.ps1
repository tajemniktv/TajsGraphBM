param(
    [ValidateSet("vs2026-game", "ninja-game", "ninja-dev")]
    [string]$Preset = "vs2026-game",
    [string]$Target = "TajsGraphBMNative",
    [switch]$SkipLintSync
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$BuildPreset = switch ($Preset) {
    "vs2026-game" { "build-vs2026-game" }
    "ninja-game" { "build-ninja-game" }
    "ninja-dev" { "build-ninja-dev" }
}

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw "cmake is not on PATH. Install CMake and reopen your shell."
}

if (($Preset -eq "ninja-game" -or $Preset -eq "ninja-dev") -and -not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    throw "Preset '$Preset' requires Ninja, but 'ninja' was not found on PATH. Use '-Preset vs2026-game' or install Ninja."
}

function Sync-CompileCommands {
    param(
        [string]$UsedPreset
    )

    $workspaceRoot = Split-Path -Parent $PSCommandPath
    $rootCompileCommands = Join-Path $workspaceRoot "compile_commands.json"
    $vsCompileCommands = Join-Path $workspaceRoot ".build/vs2026/compile_commands.json"
    $ninjaCompileCommands = Join-Path $workspaceRoot ".build/ninja-dev/compile_commands.json"

    if (Test-Path $vsCompileCommands) {
        Copy-Item -LiteralPath $vsCompileCommands -Destination $rootCompileCommands -Force
        Write-Host "[TajsGraphBM] lint db synced from vs2026: .\compile_commands.json"
        return
    }

    if (Test-Path $ninjaCompileCommands) {
        Copy-Item -LiteralPath $ninjaCompileCommands -Destination $rootCompileCommands -Force
        Write-Host "[TajsGraphBM] lint db synced from ninja-dev: .\compile_commands.json"
        return
    }

    if ($UsedPreset -eq "vs2026-game" -and (Get-Command ninja -ErrorAction SilentlyContinue)) {
        Write-Host "[TajsGraphBM] No compile_commands from VS build; configuring ninja-dev for lint db..."
        cmake --preset ninja-dev
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to configure ninja-dev for lint db."
            return
        }

        if (Test-Path $ninjaCompileCommands) {
            Copy-Item -LiteralPath $ninjaCompileCommands -Destination $rootCompileCommands -Force
            Write-Host "[TajsGraphBM] lint db synced from ninja-dev: .\compile_commands.json"
            return
        }
    }

    Write-Warning "compile_commands.json was not found. C++ clangd linting may be degraded."
}

Write-Host "[TajsGraphBM] Configuring preset: $Preset"
cmake --preset $Preset
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed for preset '$Preset' (exit code: $LASTEXITCODE)."
}

Write-Host "[TajsGraphBM] Building preset: $BuildPreset"
$buildArgs = @("--build", "--preset", $BuildPreset)
if ($Target -and $Target.Trim() -ne "") {
    $buildArgs += @("--target", $Target)
    Write-Host "[TajsGraphBM] Build target: $Target"
}
cmake @buildArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed for preset '$BuildPreset' target '$Target' (exit code: $LASTEXITCODE)."
}

Write-Host "[TajsGraphBM] Done. Deployed: .\dlls\main.dll"
if (-not $SkipLintSync) {
    Sync-CompileCommands -UsedPreset $Preset
}
if (Test-Path ".\compile_commands.json") {
    Write-Host "[TajsGraphBM] compile_commands: .\compile_commands.json"
}
