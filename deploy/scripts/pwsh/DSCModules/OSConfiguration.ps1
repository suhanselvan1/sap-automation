Configuration OSConfiguration
{
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
            Drive       = 'D'
            InitialSize = $VirtualMemorySize
            MaximumSize = $VirtualMemorySize
        }
    }
}

OSConfiguration

Start-DscConfiguration OSConfiguration -Wait -Verbose
