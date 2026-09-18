# 手动签名 Android APK（Godot preset 用 signed=false 导出后调用）
# 用法: .\tools\sign_android.ps1 [-Source build\android\gu-zhenren.apk]
param(
    [string]$Source = (Join-Path $PSScriptRoot "..\build\android\gu-zhenren.apk"),
    [string]$Out = (Join-Path $PSScriptRoot "..\build\android\gu-zhenren-signed.apk")
)
$ErrorActionPreference = "Stop"
$sdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$ks = Join-Path $env:LOCALAPPDATA "Android\debug.keystore"
$apksigner = Join-Path $sdk "build-tools\34.0.0\apksigner.bat"
if (-not (Test-Path $apksigner)) { throw "apksigner not found: $apksigner" }
if (-not (Test-Path $ks)) { throw "debug.keystore not found: $ks" }
& $apksigner sign --ks $ks --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $Out $Source
if ($LASTEXITCODE -ne 0) { throw "apksigner sign failed (exit $LASTEXITCODE)" }
& $apksigner verify $Out
if ($LASTEXITCODE -ne 0) { throw "apksigner verify failed (exit $LASTEXITCODE)" }
Write-Output "SIGNED_OK $Out"
