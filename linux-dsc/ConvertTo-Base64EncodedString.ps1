<#
    .SYNOPSIS
        This script will convert the contents of the given path to a base64 encoded string.

    .DESCRIPTION
        This script will convert the contents of the given path to a base64 encoded string. This is
        used in conjunction with the Custom Data template parameter, in order to leverage cloud-init
        pre-deployment script.

    .PARAMETER Path
        Path for pre-deployment bash script to base64 encode.

    .PARAMETER Encoding
        Text encoding, ASCII or UTF8

    .EXAMPLE
        .\ConvertTo-Base64EncodedString.ps1 -Path C:\dev\cloud-init-script.sh -TextEncoding UTF8
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path -Path $_})]
    [String]
    $Path,

    [Parameter()]
    [ValidateSet('ASCII', 'UTF8')]
    $Encoding = 'UTF8'
)

$rawString = Get-Content @PSBoundParameters -Raw
$encodedString = [System.Text.Encoding]::$Encoding.GetBytes($rawString)
return [System.Convert]::ToBase64String($encodedString)
