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
        [string]$DomainName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$UsrSapPath

    )
    
    Import-DSCResource -ModuleName NetworkingDsc
    Import-DSCResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DSCResource -ModuleName WindowsDefender

    $VirtualMemorySize = [int](((Get-Volume -DriveLetter D).Size/1048576)-2048)

    Node "localhost"
    {
        #Enable .Net3.5
        WindowsFeature Net35
        {
            Name = "NET-Framework-Features"
            Ensure = "Present"
        }

        # Add inbound firewall rule for SAP ports
        Firewall AddFirewallRule
        {
            Name                  = 'SAPFirewallRule'
            DisplayName           = 'SAP Inbound Firewall Rule'
            Group                 = 'SAP Firewall Rule Group'
            Ensure                = 'Present'
            Enabled               = 'True'
            Profile               = ('Domain', 'Private','Public')
            Direction             = 'Inbound'
            LocalPort             = ('3200-3299','8000-8099','44300-44399','30000-30099','50000-50020','1128','1129','4237','4239','3300-3399','3600-3699','15','30013-30049','50200-50205','8100-8105','44300-44305','8000-8005','50010-50015','30010-30015','8010-8015','50110-50115','30100-30115','443','3300-3310','3600-3610','3900-3910')
            Protocol              = 'TCP'
            Description           = 'SAP Inbound Firewall Rule'
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

        # Configure Windows Deefender
        WindowsDefender DefenderExclusion
        {
        IsSingleInstance = 'yes'
        ExclusionPath = ("$UsrSapPath")
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

Start-DscConfiguration OSConfiguration -Wait -Verbose -Force
