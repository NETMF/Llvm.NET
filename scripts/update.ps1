& (Join-Path $PSScriptRoot 'bootstrap.ps1')

Write-Information "Updating submodules"
git submodule update --init --recursive
