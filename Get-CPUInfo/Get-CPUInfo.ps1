function Get-CPUInfo {
   <#
.SYNOPSIS
Gets CPU information from the local system.

.DESCRIPTION
Retrieves details about installed processors using CIM. By default, it returns a readable summary.
Use -Raw to get the full CIM objects.

.PARAMETER Raw
Returns the full CIM object(s) instead of a simplified view.

.EXAMPLE
Get-CPUInfo
Shows a readable summary of all CPUs.

.EXAMPLE
Get-CPUInfo -Raw
Returns the full CIM object(s).

.EXAMPLE
(Get-CPUInfo -Raw)[0].Name
Gets the name of the first processor from raw output.

.NOTES
Author: ConnectTek  
Version: 1.0
#>

    # Allows advanced function features like -Verbose and parameter binding
    [CmdletBinding()]

    # Declares output types (custom object or CIM instance)
    [OutputType([pscustomobject], [Microsoft.Management.Infrastructure.CimInstance])]

    param (
        # If -Raw is used, return full CIM objects instead of custom view
        [switch]$Raw
    )

    # Writes a verbose message if -Verbose is used
    Write-Verbose "Retrieving CPU information..."

    try {
        # Gets CPU info using CIM (Common Information Model)
        $cpus = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
    }
    catch {
        # If the command fails, write an error and exit the function
        Write-Error "Failed to retrieve CPU info: $($_.Exception.Message)"
        return
    }

    # If -Raw is used, return the full set of CIM objects directly
    if ($Raw) {
        return $cpus
    }

    # Formats each CPU object into a simpler custom object
    foreach ($cpu in $cpus) {
        [pscustomobject]@{
            'Name'                     = $cpu.Name                         
            'Manufacturer'             = $cpu.Manufacturer                 
            'Socket Designation'       = $cpu.SocketDesignation            
            'Number Of Cores'          = $cpu.NumberOfCores                
            'Number Of Logical Processors' = $cpu.NumberOfLogicalProcessors  
            'Max Clock Speed (MHz)'    = $cpu.MaxClockSpeed                

            # Translates architecture code to readable form
            'Architecture'             = switch ($cpu.Architecture) {
                                            0 { 'x86' }
                                            1 { 'MIPS' }
                                            2 { 'Alpha' }
                                            3 { 'PowerPC' }
                                            5 { 'ARM' }
                                            6 { 'Itanium-based systems' }
                                            9 { 'x64' }
                                            default { "Unknown ($($cpu.Architecture))" }
                                        }

            'Processor ID'             = $cpu.ProcessorId                 
            'Revision'                 = $cpu.Revision                             
        }
    }
}

