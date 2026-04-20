param(
    [ValidateSet("vs2026-game", "ninja-game", "ninja-dev")]
    [string]$Preset = "vs2026-game",
    [string]$Target = "TajsGraphBMNative",
    [switch]$SkipLintSync
)

Write-Warning "build_cppui.ps1 is deprecated. Use .\\build_native.ps1"
& "$PSScriptRoot\build_native.ps1" -Preset $Preset -Target $Target -SkipLintSync:$SkipLintSync
