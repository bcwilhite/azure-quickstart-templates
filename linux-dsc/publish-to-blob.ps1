<#
    This script publishes templates and associated scripts into your Azure Storage account, and generates Azure Portal link for deployment.
    Replace variables with your environment details.
#>

Param(
    [string]
    [Parameter(Mandatory = $true)]
    $resourceGroupName,

    [string]
    [Parameter(Mandatory = $true)]
    $storageAccountName,

    [string]
    [Parameter(Mandatory = $false)]
    $containerName = "artifacts"
)

$azureDeployFile = "mainTemplate.json"
$createUIDefFile = "createUiDefinition.json"

$ErrorActionPreference = "Stop"

$context = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context

if (-not(Get-AzStorageContainer -Prefix $containerName -Context $context)) {
    New-AzStorageContainer -Name $containerName -Context $context -Permission Container
}

Get-ChildItem -Path ".\artifacts" -File -Recurse | Set-AzStorageBlobContent -Container $containerName -Context $context -Force

$azureDeployUrl = New-AzStorageBlobSASToken -Container $containerName -Blob (Split-Path $azureDeployFile -leaf) -Context $context -FullUri -Permission r
$createUIDefUrl = New-AzStorageBlobSASToken -Container $containerName -Blob (Split-Path $createUIDefFile -leaf) -Context $context -FullUri -Permission r

$azureDeployUrlEncoded = [uri]::EscapeDataString($azureDeployUrl)
$createUIDefUrlEncoded = [uri]::EscapeDataString($createUIDefUrl)
$deployUrl = "https://portal.azure.com/#create/Microsoft.Template/uri/$($azureDeployUrlEncoded)/createUIDefinitionUri/$($createUIDefUrlEncoded)"
$deployUrl