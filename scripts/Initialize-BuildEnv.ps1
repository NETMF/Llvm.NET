if( !$env:__LLVM_BUILD_INITIALIZED )
{
    $env:PSModulePath = "$env:PSModulePath;$PSScriptRoot"
    Import-Module Llvm-Build

    Initialize-BuildEnvironment
}
