Import-Module $PSScriptRoot\..\Helper.psm1 -Verbose:$false

# Localized messages
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
CheckingZoneMessage          = Checking DNS server zone with name '{0}' is '{1}'...
AddingZoneMessage            = Adding DNS server zone '{0}' ...
RemovingZoneMessage          = Removing DNS server zone '{0}' ...

CheckPropertyMessage         = Checking DNS server zone property '{0}' ...
NotDesiredPropertyMessage    = DNS server zone property '{0}' is not correct. Expected '{1}', actual '{2}'
SetPropertyMessage           = DNS server zone property '{0}' is set
'@
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('None','NonsecureAndSecure','Secure')]
        [System.String]
        $DynamicUpdate = 'Secure',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Custom','Domain','Forest','Legacy')]
        [System.String]
        $ReplicationScope,

        [Parameter()]
        [System.String]
        $DirectoryPartitionName,

        [Parameter()]
        [System.String]
        $ComputerName,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present'
    )

    Assert-Module -Name 'DNSServer'
    Write-Verbose ($LocalizedData.CheckingZoneMessage -f $Name, $Ensure)

    $getParams = @{
        Name = $Name
        ErrorAction = 'SilentlyContinue'
    }

    if ($ComputerName)
    {
        $cimSessionParams = @{
            ErrorAction = 'SilentlyContinue'
            ComputerName = $ComputerName
        }

        if ($Credential)
        {
            $cimSessionParams += @{Credential = $Credential}
        }
        
        $cimSession = New-CimSession @cimSessionParams
        $getParams += @{CimSession = $cimSession}
    }

    $dnsServerZone = Get-DnsServerZone @getParams

    if($ComputerName) 
    {
        Remove-CimSession $cimSession
    }
    
    $targetResource = @{
        Name = $dnsServerZone.ZoneName
        DynamicUpdate = $dnsServerZone.DynamicUpdate
        ReplicationScope = $dnsServerZone.ReplicationScope
        DirectoryPartitionName = $dnsServerZone.DirectoryPartitionName
        Ensure = if ($null -eq $dnsServerZone) { 'Absent' } else { 'Present' }
    }
    return $targetResource
} #end function Get-TargetResource

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('None','NonsecureAndSecure','Secure')]
        [System.String]
        $DynamicUpdate = 'Secure',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Custom','Domain','Forest','Legacy')]
        [System.String]
        $ReplicationScope,

        [Parameter()]
        [System.String]
        $DirectoryPartitionName,

        [Parameter()]
        [System.String]
        $ComputerName,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present'
    )
    $targetResource = Get-TargetResource @PSBoundParameters
    $targetResourceInCompliance = $true
    
    if ($Ensure -eq 'Present')
    {
        if ($targetResource.Ensure -eq 'Present')
        {
            if ($targetResource.DynamicUpdate -ne $DynamicUpdate)
            {
                Write-Verbose ($LocalizedData.NotDesiredPropertyMessage -f 'DynamicUpdate', $DynamicUpdate, $targetResource.DynamicUpdate)
                $targetResourceInCompliance = $false
            }
            if ($targetResource.ReplicationScope -ne $ReplicationScope)
            {
                Write-Verbose ($LocalizedData.NotDesiredPropertyMessage -f 'ReplicationScope', $ReplicationScope, $targetResource.ReplicationScope)
                $targetResourceInCompliance = $false
            }
            if ($DirectoryPartitionName -and $targetResource.DirectoryPartitionName -ne $DirectoryPartitionName)
            {
                Write-Verbose ($LocalizedData.NotDesiredPropertyMessage -f 'DirectoryPartitionName', $DirectoryPartitionName, $targetResource.DirectoryPartitionName)
                $targetResourceInCompliance = $false
            }
        }
        else
        {
            # Dns zone is present and needs removing
            Write-Verbose ($LocalizedData.NotDesiredPropertyMessage -f 'Ensure', 'Present', 'Absent')
            $targetResourceInCompliance = $false
        }
    }
    else
    {
        if ($targetResource.Ensure -eq 'Present')
        {
            ## Dns zone is absent and should be present
            Write-Verbose ($LocalizedData.NotDesiredPropertyMessage -f 'Ensure', 'Absent', 'Present')
            $targetResourceInCompliance = $false
        }
    }
    return $targetResourceInCompliance
} #end function Test-TargetResource

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateSet('None','NonsecureAndSecure','Secure')]
        [System.String]
        $DynamicUpdate = 'Secure',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Custom','Domain','Forest','Legacy')]
        [System.String]
        $ReplicationScope,

        [Parameter()]
        [System.String]
        $DirectoryPartitionName,

        [Parameter()]
        [System.String]
        $ComputerName,

        [Parameter()]
        [pscredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present'
    )
    Assert-Module -Name 'DNSServer'
    $targetResource = Get-TargetResource @PSBoundParameters
    if ($Ensure -eq 'Present')
    {
        if ($targetResource.Ensure -eq 'Present')
        {
            ## Update the existing zone
            $updateParams = @{
                Name = $targetResource.Name
            }
            if ($ComputerName)
            {
                $cimSessionParams = @{
                    ErrorAction = 'SilentlyContinue'
                    ComputerName = $ComputerName
                }
                
                if ($Credential)
                {
                    $cimSessionParams += @{Credential = $Credential}
                }
                $cimSession = New-CimSession @cimSessionParams
                $updateParams += @{CimSession = $cimSession}
            }
            if ($targetResource.DynamicUpdate -ne $DynamicUpdate)
            {
                $updateParams += @{DynamicUpdate = $DynamicUpdate}
                Write-Verbose ($LocalizedData.SetPropertyMessage -f 'DynamicUpdate')
            }
            if ($targetResource.ReplicationScope -ne $ReplicationScope)
            {
                $updateParams += @{ReplicationScope = $ReplicationScope}
                Write-Verbose ($LocalizedData.SetPropertyMessage -f 'ReplicationScope')
            }
            if ($DirectoryPartitionName -and $targetResource.DirectoryPartitionName -ne $DirectoryPartitionName)
            {
                $updateParams += @{DirectoryPartitionName = $DirectoryPartitionName}
                Write-Verbose ($LocalizedData.SetPropertyMessage -f 'DirectoryPartitionName')
            }
            Set-DnsServerPrimaryZone @updateParams
        }
        elseif ($targetResource.Ensure -eq 'Absent')
        {
            ## Create the zone
            Write-Verbose ($LocalizedData.AddingZoneMessage -f $targetResource.Name)
            $addParams = @{
                Name = $Name
                DynamicUpdate = $DynamicUpdate
                ReplicationScope = $ReplicationScope
            }
            if ($ComputerName)
            {
                $cimSessionParams = @{
                    ErrorAction = 'SilentlyContinue'
                    ComputerName = $ComputerName
                }
                if ($Credential)
                {
                    $cimSessionParams += @{Credential = $Credential}
                }
                $cimSession = New-CimSession @cimSessionParams
                $addParams += @{CimSession = $cimSession}
            }
            if ($DirectoryPartitionName)
            {
                $addParams += @{
                    DirectoryPartitionName = $DirectoryPartitionName
                }
            }
            Add-DnsServerPrimaryZone @addParams
        }
    }
    elseif ($Ensure -eq 'Absent')
    {
        # Remove the DNS Server zone
        Write-Verbose ($LocalizedData.RemovingZoneMessage -f $targetResource.Name)
        $removeParams = @{
            Name = $targetResource.Name
            Force = $true
        }

        if ($ComputerName)
        {
            $cimSessionParams = @{
                ErrorAction = 'SilentlyContinue'
                ComputerName = $ComputerName
            }

            if ($Credential)
            {
                $cimSessionParams += @{Credential = $Credential}
            }
            $cimSession = New-CimSession @cimSessionParams
            $removeParams += @{CimSession = $cimSession}
        }
        Remove-DnsServerZone @removeParams
    }

    if($ComputerName) 
    {
        Remove-CimSession $cimSession
    }
} #end function Set-TargetResource
