function Find-VSInstance
{
    Install-Module VSSetup -Scope CurrentUser | Out-Null
    return Get-VSSetupInstance -All | select -First 1
}


# Main Script entry point -----------
if( $env:APPVEYOR )
{
    $loggerArgs = '/logger:Appveyor'
}

$vsInstance = Find-VSInstance
$vstest = [System.IO.Path]::Combine($vsInstance.InstallationPath, 'Common7','IDE','CommonExtensions','Microsoft','TestWindow','vstest.console.exe')

Write-Information 'Running tests as win32'
& $vstest .\BuildOutput\bin\Release\net47\Llvm.NETTests.dll /InIsolation /Settings:src\win32.runsettings $loggerArgs

Write-Information 'Running tests as x64'
& $vstest .\BuildOutput\bin\Release\net47\Llvm.NETTests.dll /InIsolation /Settings:src\x64.runsettings $loggerArgs 
