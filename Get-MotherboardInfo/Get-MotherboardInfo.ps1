function Get-MotherboardInfo {
    <#
.SYNOPSIS
    Retrieves motherboard (baseboard) information from local or remote computers.

.DESCRIPTION
    The Get-MotherboardInfo function collects motherboard data using WMI/CIM and optionally exports the results 
    in various formats including CSV, JSON, TXT, XML, or HTML. It supports querying multiple computer names and 
    includes a raw output option for advanced use cases.

.PARAMETER ComputerName
    One or more computer names to query. Defaults to the local computer if not specified.

.PARAMETER ExportFormat
    Optional. Specifies the format for exporting results. Valid options are: CSV, JSON, TXT, XML, HTML.

.PARAMETER ExportPath
    Optional. Path where the export file will be saved. If a folder is provided, a filename is auto-generated.

.PARAMETER Raw
    If specified, returns raw WMI/CIM objects instead of parsed fields.

.EXAMPLE
    Get-MotherboardInfo

    Retrieves motherboard info from the local machine and returns structured data to the console.

.EXAMPLE
    Get-MotherboardInfo -ComputerName "PC1","PC2" -ExportFormat JSON

    Queries motherboard data from PC1 and PC2 and exports the results as a JSON file to the temp directory.

.EXAMPLE
    Get-MotherboardInfo -ExportFormat CSV -ExportPath "C:\Users\computer\Downloads"

    Exports the local motherboard info to a CSV file in the specified directory.

.NOTES
    Author: ConnectTek
    Last Updated: 20/07/2025
    Requires: PowerShell 5.1 or later
#>

    [CmdletBinding(
        SupportsShouldProcess = $False,
        ConfirmImpact = 'None'
    )]
    param (
        [Parameter(Mandatory = $false)]
        [ValidatePattern('^[a-zA-Z0-9\-\.]{1,255}$')]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false)]
        [string]$ExportFormat,

        [Parameter(Mandatory = $false)]
        [string]$ExportPath,

        [Parameter(Mandatory = $false)]
        [switch]$Raw
    )

    # --- define allowed export formats ---
    $validFormats = @('CSV','JSON','TXT','XML','HTML')

    # --- collect results from all computers ---
    $results = @()

    # --- define script block to run locally or remotely ---
    $scriptBlock = {
        param($rawFlag)

        $mb = $null

        try {
            $mb = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
        }
        catch {
            Write-Error "[$env:COMPUTERNAME] Failed to retrieve motherboard info: $_"
            return
        }

        if ($rawFlag) {
            return [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME
                Motherboard  = $mb
            }
        }
        else {
            return [pscustomobject]@{
                'ComputerName' = $env:COMPUTERNAME
                'Manufacturer' = $mb.Manufacturer
                'Product'      = $mb.Product
                'SerialNumber' = $mb.SerialNumber
                'Version'      = $mb.Version
                'PartNumber'   = $mb.PartNumber
            }
        }
    }

    foreach ($comp in $ComputerName) {
        try {
            if ($comp -eq $env:COMPUTERNAME) {
                $results += & $scriptBlock $Raw
            }
            else {
                $output = Invoke-Command -ComputerName $comp -ScriptBlock $scriptBlock -ArgumentList $Raw -ErrorAction Stop
                $results += $output
            }
        }
        catch {
            Write-Error "Error collecting data from '$comp': $_"
        }
    }

    # --- return early if Raw ---
    if ($Raw) { return $results }

    # --- if no ExportFormat, just return the data, do not save ---
    if (-not $ExportFormat) {
        return $results
    }

    # --- validate ExportFormat manually ---
    if ($ExportFormat -notin $validFormats) {
        Write-Error "Invalid ExportFormat '$ExportFormat'. Valid options are: $($validFormats -join ', ')"
        return
    }

    # --- build default export path if not supplied ---
    if (-not $ExportPath) {
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $ExportPath = Join-Path $env:TEMP "Motherboard_$stamp.$($ExportFormat.ToLower())"
    }
    elseif (Test-Path $ExportPath -PathType Container) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $ExportPath = Join-Path $ExportPath "Motherboard_$stamp.$($ExportFormat.ToLower())"
    }

    # --- export with error handling ---
    try {
        switch ($ExportFormat) {
            'CSV'  { $results | Export-Csv -Path $ExportPath -NoTypeInformation -Force }
            'JSON' { $results | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportPath -Force }
            'TXT'  { $results | Out-String | Set-Content -Path $ExportPath -Force }
            'XML'  { $results | ConvertTo-Xml -As String -Depth 5 | Set-Content -Path $ExportPath -Force }
            'HTML' { $results | ConvertTo-Html | Set-Content -Path $ExportPath -Force }
        }

        Write-Verbose "Export successful. Saved to: $ExportPath"
    }
    catch {
        Write-Error "Failed to export to '$ExportPath': $_"
        return
    }

    return $ExportPath
}

