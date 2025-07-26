function Get-InstalledSoftwareInfo {
<#
.SYNOPSIS
Retrieves a list of installed software from local or remote Windows computers.

.DESCRIPTION
This utility-style function scans registry locations for installed software entries 
on one or more Windows machines. It supports optional filtering by software name 
and allows exporting the results to CSV, JSON, XML, or TXT format.

.PARAMETER ComputerName
One or more computer names to query. Defaults to the local computer if not specified.

.PARAMETER SoftwareFilter
Optional string to filter software results by name (wildcard match). For example, "Chrome".

.PARAMETER ExportFormat
Specifies the export format. Acceptable values are: CSV, JSON, XML, or TXT.

.PARAMETER ExportPath
Specifies the full output file path or a folder to save the export. 
If a folder is passed, a timestamped filename will be generated automatically.
If omitted, a file will be saved to the system's temporary folder.

.OUTPUTS
[PSCustomObject] representing installed software entries.

.EXAMPLE
Get-InstalledSoftwareInfo

Scans the local computer and prints installed software in table format.

.EXAMPLE
Get-InstalledSoftwareInfo -ComputerName "PC1","PC2" -SoftwareFilter "Office"

Queries two remote computers for software matching "Office".

.EXAMPLE
Get-InstalledSoftwareInfo -SoftwareFilter "Chrome" -ExportFormat CSV -ExportPath "C:\Exports"

Scans the local machine for Chrome, exporting the result as a CSV file.

.NOTES
Author: ConnectTek
Version: 1.0
#>
    [CmdletBinding(SupportsShouldProcess = $false, ConfirmImpact = 'None')]
    [OutputType([PSCustomObject])]

    param (
        # Target computer(s) to scan; defaults to local machine
        [Parameter(Mandatory = $false, HelpMessage = "Name(s) of the computer(s) to query.")]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        # Optional software name filter (wildcard match)
        [Parameter(Mandatory = $false)]
        [string]$SoftwareFilter,

        # Desired export format for output
        [Parameter(Mandatory = $false)]
        [ValidateSet("CSV", "JSON", "XML", "TXT")]
        [string]$ExportFormat,

        # File path or folder where the export will be saved
        [Parameter(Mandatory = $false)]
        [string]$ExportPath
    )

    # Stores results from all queried computers
    $AllResults = @()

    foreach ($comp in $ComputerName) {
        Write-Verbose "Querying $comp..."

        Write-Output ""
        Write-Output "Computer Name: $comp"

        # Remote script to gather installed software from registry
        $scriptBlock = {
            param ($SoftwareFilter)

            try {
                Write-Verbose "Gathering software details..."

                # Registry paths where installed software info is stored
                $RegistryPath = @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
                )

                # Collect and filter software based on optional name filter
                $SoftwareList = $RegistryPath |
                    ForEach-Object { Get-ItemProperty $_ -ErrorAction Stop } |
                    Where-Object {
                        $_.DisplayName -and (
                            -not $SoftwareFilter -or
                            $_.DisplayName -like "*$SoftwareFilter*"
                        )
                    } |
                    ForEach-Object {
                        # Format each software entry into a custom object
                        [PSCustomObject]@{
                            'Name'             = $_.DisplayName
                            'Version'          = $_.DisplayVersion
                            'Vendor'           = $_.Publisher
                            'Size (MB)'        = if ($_.EstimatedSize -as [int]) {
                                                     [math]::Round($_.EstimatedSize / 1024, 2)
                                                 } else {
                                                     $null
                                                 }
                            'Install Date'     = if ($_.InstallDate -as [int]) {
                                                     [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
                                                 } else {
                                                     $null
                                                 }
                            'Install Location' = $_.InstallLocation
                            'Install Source'   = $_.InstallSource
                            'ShortCut Path'    = $_.DisplayIcon
                        }
                    }

                # Return sorted, deduplicated list
                $SoftwareList | Sort-Object Name -Unique
            }
            catch {
                Write-Error "[$env:COMPUTERNAME] Error retrieving software info: $_"
            }
        }

        # Run script block locally or remotely
        $results = if ($comp -eq $env:COMPUTERNAME) {
            & $scriptBlock $SoftwareFilter
        } else {
            Invoke-Command -ComputerName $comp -ScriptBlock $scriptBlock -ArgumentList $SoftwareFilter
        }

        if ($results) {
            $AllResults += $results                # Add to master list
            $results | Format-Table -AutoSize      # Show to console
        }
    }

    # Use temp directory if no ExportPath was provided
    if (-not $ExportPath) {
        $ExportPath = [System.IO.Path]::GetTempPath()
        Write-Verbose "No ExportPath specified. Defaulting to temp folder: $ExportPath"
    }

    # Only export if both ExportPath and ExportFormat are valid and results exist
    if ($ExportPath -and $ExportFormat -and $AllResults.Count -gt 0) {

        # If a folder is provided, auto-generate filename based on timestamp
        if (Test-Path $ExportPath -PathType Container) {
            $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
            $extension = switch ($ExportFormat) {
                'CSV'  { 'csv' }
                'JSON' { 'json' }
                'XML'  { 'xml' }
                'TXT'  { 'txt' }
            }
            $filename = "InstalledSoftware_$timestamp.$extension"
            $ExportPath = Join-Path $ExportPath $filename
            Write-Verbose "Auto-naming export file: $ExportPath"
        }

        # Create header comment line with all queried computer names
        $computerNames = ($ComputerName -join ', ')
        $headerLine = "# Computer Name(s): $computerNames"

        # Export results in the chosen format
        switch ($ExportFormat) {
            'CSV' {
                $temp = New-TemporaryFile                          
                $AllResults | Export-Csv -Path $temp -NoTypeInformation -Encoding UTF8
                Set-Content -Path $ExportPath -Value $headerLine  # Write header
                Get-Content -Path $temp | Add-Content -Path $ExportPath
                Remove-Item $temp
            }
            'JSON' {
                $jsonData = $AllResults | ConvertTo-Json -Depth 4
                Set-Content -Path $ExportPath -Value $headerLine
                Add-Content -Path $ExportPath -Value $jsonData
            }
            'XML' {
                $AllResults | Export-Clixml -Path $ExportPath     
            }
            'TXT' {
                Set-Content -Path $ExportPath -Value $headerLine
                $AllResults | Out-String | Add-Content -Path $ExportPath
            }
        }

        Write-Host "Exported software list to $ExportPath as $ExportFormat"
    }
}

