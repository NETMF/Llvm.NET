if( !$env:__LLVM_BUILD_INITIALIZED )
{
    $env:PSModulePath = "$env:PSModulePath;$PSScriptRoot"
    Write-Information "Importing module Llvm-Build"
    Import-Module Llvm-Build

    Write-Information "Initializing build environment for this repository"
    Initialize-BuildEnvironment
}
