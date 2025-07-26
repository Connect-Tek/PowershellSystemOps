function Get-OSInfo {
    <#
.SYNOPSIS
    Retrieves operating system information from local or remote computers.

.DESCRIPTION
    The Get-OSInfo function collects OS details using WMI/CIM and optionally exports 
    the results in various formats including CSV, JSON, TXT, XML, or HTML. It supports querying 
    multiple computer names and includes a raw output option for advanced use cases.

.PARAMETER ComputerName
    One or more computer names to query. Defaults to the local computer if not specified.

.PARAMETER ExportFormat
    Optional. Specifies the format for exporting results. Valid options are: CSV, JSON, TXT, XML, HTML.

.PARAMETER ExportPath
    Optional. Path where the export file will be saved. If a folder is provided, a filename is auto-generated.

.PARAMETER Raw
    If specified, returns raw WMI/CIM objects instead of parsed fields.

.EXAMPLE
    Get-OSInfo

    Retrieves OS info from the local machine and returns structured data to the console.

.EXAMPLE
    Get-OSInfo -ComputerName "PC1","PC2" -ExportFormat JSON

    Queries OS data from PC1 and PC2 and exports the results as a JSON file to the temp directory.

.EXAMPLE
    Get-OSInfo -ExportFormat CSV -ExportPath "C:\Users\computer\Downloads"

    Exports the local OS info to a CSV file in the specified directory.

.NOTES
    Author: ConnectTek
    Last Updated: 25/07/2025
    Requires: PowerShell 5.1 or later
#>

    [CmdletBinding()]
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

    $validFormats = @('CSV','JSON','TXT','XML','HTML')
    $results = @()

    $scriptBlock = {
        param($rawFlag)

        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        }
        catch {
            Write-Error "[$env:COMPUTERNAME] Failed to retrieve OS info: $_"
            return
        }

        $regValues = $null
        try {
            $regValues = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' `
                -Name DisplayVersion, InstallationType, ReleaseId, EditionID, LCUVer, ProductId -ErrorAction Stop
        }
        catch {
            Write-Warning "[$env:COMPUTERNAME] Failed to access registry info: $_"
        }

        if ($rawFlag) {
            return [pscustomobject]@{
                ComputerName = $env:COMPUTERNAME
                OS           = $os
                Registry     = $regValues
            }
        }
        else {
            return [pscustomobject]@{
                'Computer Name'                     = $env:COMPUTERNAME
                'OS Name'                           = ($os.Caption -replace '^Microsoft\s+', '').Trim()
                'Display Version'                   = $regValues.DisplayVersion
                'Build Number'                      = $os.BuildNumber
                'Cumulative Update Version'         = $regValues.LCUVer
                'Architecture'                      = $os.OSArchitecture
                'Install Date'                      = $os.InstallDate
                'Last BootUp Time'                  = $os.LastBootUpTime
                'Product Id'                        = $regValues.ProductId
                'Registered User'                   = $os.RegisteredUser
                'Organization'                      = $os.Organization
                'Boot Device'                       = $os.BootDevice
                'System Directory'                  = $os.SystemDirectory
                'Windows Directory'                 = $os.WindowsDirectory
                'Product Type'                      = switch ($os.ProductType) {
                                                          1 { 'Workstation' }
                                                          2 { 'Domain Controller' }
                                                          3 { 'Server' }
                                                          default { "Unknown ($($os.ProductType))" }
                                                    }                                   
                'OS Language'                       = $os.OSLanguage
                'Locale'                            = $os.Locale 
                
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

    if ($Raw) { return $results }

    if (-not $ExportFormat) {
        return $results
    }

    if ($ExportFormat -notin $validFormats) {
        Write-Error "Invalid ExportFormat '$ExportFormat'. Valid options are: $($validFormats -join ', ')"
        return
    }

    if (-not $ExportPath) {
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $ExportPath = Join-Path $env:TEMP "OSInfo_$stamp.$($ExportFormat.ToLower())"
    }
    elseif (Test-Path $ExportPath -PathType Container) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $ExportPath = Join-Path $ExportPath "OSInfo_$stamp.$($ExportFormat.ToLower())"
    }

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
    }

    return $ExportPath
}
