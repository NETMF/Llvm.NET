$bootstrap = Join-Path $PSScriptRoot 'bootstrap.ps1'
& $bootstrap

$buildScript = Join-Path $PSScriptRoot 'Build-Llvm.ps1'
& $buildScript -Build -Platform $env:PLATFORM -Configuration $env:CONFIGURATION
