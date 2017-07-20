#
# File: Get-HelpByMarkdown.ps1
#
# Author: Akira Sugiura (urasandesu@gmail.com)
#
#
# Copyright (c) 2014 Akira Sugiura
#
#  This software is MIT License.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#

# Significantly re-worked from the original to make it more readable and skip
# sections that are empty.

function EncodePartOfHtml
{
    param (
        [string]
        $Value
    )

    ($Value -replace '<', '&lt;') -replace '>', '&gt;'
}

function GetCode
 {
    param (
        $Example
    )
    $codeAndRemarks = (($Example | Out-String) -replace ($Example.title), '').Trim() -split "`r`n"

    $code = New-Object "System.Collections.Generic.List[string]"
    for ($i = 0; $i -lt $codeAndRemarks.Length; $i++) {
        if ($codeAndRemarks[$i] -eq 'DESCRIPTION' -and $codeAndRemarks[$i + 1] -eq '-----------') {
            break
        }
        if (1 -le $i -and $i -le 2) {
            continue
        }
        $code.Add($codeAndRemarks[$i])
    }

    $code -join "`r`n"
}

function GetRemark
{
    param (
        $Example
    )
    $codeAndRemarks = (($Example | Out-String) -replace ($Example.title), '').Trim() -split "`r`n"

    $isSkipped = $false
    $remark = New-Object "System.Collections.Generic.List[string]"
    for ($i = 0; $i -lt $codeAndRemarks.Length; $i++) {
        if (!$isSkipped -and $codeAndRemarks[$i - 2] -ne 'DESCRIPTION' -and $codeAndRemarks[$i - 1] -ne '-----------') {
            continue
        }
        $isSkipped = $true
        $remark.Add($codeAndRemarks[$i])
    }

    $remark -join "`r`n"
}

function GetSyntax
{
    param (
        $fullHelp
    )

    try
    {
        # if A UI is present - force the output line length to avoid wrapping line endings in the syntax
        if ($Host.UI.RawUI)
        {
            $rawUI = $Host.UI.RawUI
            $oldSize = $rawUI.BufferSize
            $typeName = $oldSize.GetType().FullName
            $newSize = New-Object $typeName (500, $oldSize.Height)
            $rawUI.BufferSize = $newSize
        }

        $syntax = ($fullHelp.syntax | Out-String)
        $syntaxLines = ($syntax -split "(\r?\n)+") | ?{ ![string]::IsNullOrWhitespace($_) }
        foreach($syntaxItem in $syntaxLines)
        {
            $syntaxElements = $syntaxItem -split ' '
    
            $syntaxName = [System.IO.Path]::GetFileName($syntaxElements[0])
            $syntaxParams = ( $syntaxElements | Select-Object -Skip 1 ) -join ' '
            "$syntaxName $syntaxParams"
        }
    }
    finally
    {
        # restore the UI settings
        if ($Host.UI.RawUI)
        {
              $rawUI = $Host.UI.RawUI
              $rawUI.BufferSize = $oldSize
        }
    }
}

function Header([int]$level, [string]$title)
{
    "$([string]::new( '#', $level )) $title"
}

function CodeBlock([string]$code, $language="")
{
    "``````$language"
    $code
    "``````"
}

function Get-HelpMarkDown( $command )
{
    $full = Get-Help $command -Full

    Header 1 ([System.IO.Path]::GetFileName($full.Name))
    if( ($full.PSobject.Properties.name -contains "Synopsis") -and $full.Synopsis )
    {
        Header 2 SYNOPSIS
        $full.Synopsis
    }

    Header 2 SYNTAX
    $syntax = GetSyntax $full
    CodeBlock -language powershell ($syntax -join ([System.Environment]::NewLine))

    if( ($full.PSobject.Properties.name -contains "description") -and $full.description )
    {
        Header 2 DESCRIPTION
        EncodePartOfHtml ($full.description | Out-String).Trim()
    }

    if( ($full.PSobject.Properties.name -contains "parameters") -and ($full.parameters) -and ($full.parameters.parameter.Count -gt 0 ))
    {
        Header 2 PARAMETERS
        foreach ($parameter in $full.parameters.parameter)
        {
            Header 3 "-$($parameter.name) ``<$($parameter.type.name)>``"
            if( $parameter.PSobject.Properties.name -contains "description") 
            {
                (($parameter.description | Out-String).Trim())
            }
            CodeBlock -code (((($parameter | Out-String).Trim() -split "`r`n")[-5..-1] | % { $_.Trim() }) -join "`r`n")
        }
    }

    if( ($full.PSobject.Properties.name -contains "inputTypes") -and ($full.inputTypes))
    {
        Header 2 INPUTS
        $($full.inputTypes.inputType.type.name)
    }

    if( ($full.PSobject.Properties.name -contains "returnValues") -and ($full.returnValues) -and ($full.returnValues.Count -gt 0 ))
    {
        Header 2 OUTPUTS
        foreach( $ret in $full.returnValues.returnValue )
        {
            $ret.type.name
        }
    }

    if( ($full.PSobject.Properties.name -contains "alertSet") -and ($full.alertSet) -and $full.alertSet.Alert )
    {
        Header 2 NOTES
        $(($full.alertSet.alert | Out-String).Trim())
    }

    if( ($full.PSobject.Properties.name -contains "examples") -and ($full.examples) -and ($full.examples.Count -gt 0 ))
    {
        Header 2 EXAMPLES
        foreach ($example in $full.examples.example)
        {
            Header 3 $(($example.title -replace '-*', '').Trim())
            CodeBlock -language powershell $(GetCode $example)
            $(GetRemark $example)
        }
    }
}

