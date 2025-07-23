function Get-DiskInfo {
    <#
.SYNOPSIS
    Retrieves disk information from local or remote computers.

.DESCRIPTION
    The Get-DiskInfo function collects disk data using PowerShell storage and CIM commands.
    It supports querying local or remote computers and can export results in CSV, JSON, TXT, XML, or HTML format.

.PARAMETER ComputerName
    One or more computer names to query. Defaults to the local computer if not specified.

.PARAMETER ExportFormat
    Optional. Specifies the format for exporting results. Valid options are: CSV, JSON, TXT, XML, HTML.

.PARAMETER ExportPath
    Optional. Path where the export file will be saved. If a folder is provided, a filename is auto-generated.

.PARAMETER Raw
    If specified, returns raw WMI/CIM objects instead of parsed fields.

.EXAMPLE
    Get-DiskInfo

.EXAMPLE
    Get-DiskInfo -ComputerName "PC1","PC2" -ExportFormat JSON

.EXAMPLE
    Get-DiskInfo -ExportFormat CSV -ExportPath "C:\DiskReports"

.NOTES
    Author: ConnectTek
    Last Updated: 23/07/2025
    Requires: PowerShell 5.1 or later
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
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
        param ($rawFlag, $targetComputer)

        try {
            $disks = Get-Disk -ErrorAction Stop
        } catch {
            Write-Error "[$targetComputer] Failed to retrieve Get-Disk: $_"
            return
        }

        try {
            $physicalDisks = Get-PhysicalDisk -ErrorAction Stop
        } catch {
            Write-Warning "[$targetComputer] Get-PhysicalDisk failed: $_"
            $physicalDisks = @()
        }

        try {
            $wmiDisks = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop
        } catch {
            Write-Warning "[$targetComputer] Get-CimInstance failed: $_"
            $wmiDisks = @()
        }

        if ($rawFlag) {
            return [pscustomobject]@{
                ComputerName  = $targetComputer
                GetDisk       = $disks
                PhysicalDisk  = $physicalDisks
                WmiDisk       = $wmiDisks
            }
        }

        $output = foreach ($disk in $disks) {
            $pd = $physicalDisks | Where-Object { $_.FriendlyName -eq $disk.FriendlyName } | Select-Object -First 1
            $wmi = $wmiDisks | Where-Object { $_.DeviceID -like "*$($disk.Number)*" } | Select-Object -First 1

            [pscustomobject][ordered]@{
                'ComputerName'        = $targetComputer
                'Number'              = $disk.Number
                'Friendly Name'       = $disk.FriendlyName
                'Serial Number'       = $wmi.SerialNumber
                'Interface Type'      = $wmi.InterfaceType
                'Bus Type'            = $disk.BusType
                'Media Type'          = $pd.MediaType
                'Can Pool'            = $pd.CanPool
                'Usage'               = $pd.Usage
                'Health Status'       = $disk.HealthStatus
                'Operational Status'  = ($disk.OperationalStatus -join ', ')
                'Is Boot'             = $disk.IsBoot
                'Is System'           = $disk.IsSystem
                'Partition Style'     = $disk.PartitionStyle
                'Size (GB)'           = [math]::Round($disk.Size / 1GB, 2)
            }
        }

        return $output
    }

    foreach ($comp in $ComputerName) {
        try {
            if ($comp -eq $env:COMPUTERNAME) {
                $results += & $scriptBlock $Raw $comp
            } else {
                $remoteOutput = Invoke-Command -ComputerName $comp -ScriptBlock $scriptBlock -ArgumentList $Raw, $comp -ErrorAction Stop
                $results += $remoteOutput
            }
        } catch {
            Write-Error "Failed to collect data from '$comp': $_"
        }
    }

    if ($Raw) {
        return $results
    }

    if (-not $ExportFormat) {
        return $results
    }

    if ($ExportFormat -notin $validFormats) {
        Write-Error "Invalid ExportFormat '$ExportFormat'. Valid options are: $($validFormats -join ', ')"
        return
    }

    if (-not $ExportPath) {
        $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
        $ExportPath = Join-Path $env:TEMP "Disk_$stamp.$($ExportFormat.ToLower())"
    } elseif (Test-Path $ExportPath -PathType Container) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $ExportPath = Join-Path $ExportPath "Disk_$stamp.$($ExportFormat.ToLower())"
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
    } catch {
        Write-Error "Failed to export to '$ExportPath': $_"
        return
    }

    return $ExportPath
}
