[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$resolver = Join-Path $PSScriptRoot 'resolve-godot.ps1'
$godot = & $resolver -Console

& $godot @GodotArgs
exit $LASTEXITCODE
