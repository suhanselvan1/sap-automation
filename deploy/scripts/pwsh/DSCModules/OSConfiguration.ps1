Configuration OSConfiguration
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $DomainCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$SwapDriveLetter,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$DomainName

    )
    
    Import-DSCResource -ModuleName NetworkingDsc
    Import-DSCResource -ModuleName ComputerManagementDsc

    $VirtualMemorySize = [int](((Get-Volume -DriveLetter D).Size/1048576)-2048)

    Node "localhost"
    {
        #Enable .Net3.5
        WindowsFeature Net35
        {
            Name = "NET-Framework-Features"
            Ensure = "Present"
        }

        #Disable domain firewall
        FirewallProfile DisableDomainFirewall
        {
            Name                  = 'Domain'
            Enabled                = 'False'
        }

        #Disable public firewall
        FirewallProfile DisablePublicFirewall
        {
            Name                  = 'Public'
            Enabled                = 'False'
        }

        #Disable private firewall
        FirewallProfile DisablePrivateFirewall
        {
            Name                  = 'Private'
            Enabled                = 'False'
        }

        #Set paging file size
        VirtualMemory PagingSettings
        {
            Type        = 'CustomSize'
            Drive       = $SwapDriveLetter
            InitialSize = $VirtualMemorySize
            MaximumSize = $VirtualMemorySize
        }

        #Join domain
        Computer JoinDomain
        {
            Name       = $ComputerName
            DomainName = $DomainName
            Credential = $DomainCredential # Credential to join to domain
        }
    }
}

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
        }
    )
}

OSConfiguration -ConfigurationData $cd

Start-DscConfiguration OSConfiguration -Wait -Verbose
