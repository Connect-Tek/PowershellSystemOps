function Get-BiosInfo {
    <#
    .SYNOPSIS
    Retrieves BIOS and system product information from the local system.

    .DESCRIPTION
    Queries the BIOS and system product information using CIM. By default, it returns a simplified summary
    including the BIOS name, version, manufacturer, serial number, and system UUID. When -Raw is specified,
    it returns the full raw CIM objects for advanced use.

    The raw output contains two properties:
      - BIOS             (from Win32_BIOS)
      - System Product   (from Win32_ComputerSystemProduct)

    These can be accessed directly for scripting or automation scenarios.

    .PARAMETER Raw
    If specified, returns the full raw CIM objects for BIOS and system product data.

    .EXAMPLE
    Get-BiosInfo
    Returns a simplified summary of BIOS and system product information.

    .EXAMPLE
    Get-BiosInfo -Raw
    Returns the full raw CIM objects for BIOS and system product.

    .EXAMPLE
    (Get-BiosInfo -Raw).BIOS.SerialNumber
    Returns the serial number from the raw BIOS object.

    .EXAMPLE
    (Get-BiosInfo -Raw).'System Product'.UUID
    Returns the UUID from the raw system product object.

    .NOTES
    Author: ConnectTek   
    Version: 1.1
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject], [Microsoft.Management.Infrastructure.CimInstance])]
    param (
        [switch]$Raw
    )

    Write-Verbose "Retrieving BIOS and system product information..."

    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to retrieve BIOS info: $($_.Exception.Message)"
        return
    }

    try {
        $sysProd = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to retrieve System Product info: $($_.Exception.Message)"
        return
    }

    if ($Raw) {
        return [pscustomobject]@{
            BIOS             = $bios
            'System Product' = $sysProd
        }
    }

    return [pscustomobject]@{
        Name                 = $bios.Name
        Version              = $bios.Version
        Manufacturer         = $bios.Manufacturer
        'Serial Number'      = $bios.SerialNumber
        'Release Date'       = $bios.ReleaseDate
        SMBiosBiosVersion    = $bios.SMBiosBiosVersion
        UUID                 = $sysProd.UUID
        'Product Name'       = $sysProd.Name
        'Identifying Number' = $sysProd.IdentifyingNumber
    }
}
