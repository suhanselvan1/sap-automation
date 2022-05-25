Configuration OSConfiguration
{
    param
    (
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$DomainName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$SwapDriveLetter,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$VirtualMemorySizeinMB

    )
    
    Import-DSCResource -ModuleName NetworkingDsc, ComputerManagementDsc, PSDesiredStateConfiguration

    Node "localhost"
    {
        #Enable .Net3.5
        WindowsFeature Net35
        {
            Name = "NET-Framework-Features"
            Ensure = "Present"
        }

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

        WindowsFeature FCCmd {
            Name = "RSAT-Clustering-CmdInterface"
            Ensure = "Present"
        }

        WindowsFeature FCMgmt {
            Name = "RSAT-Clustering-Mgmt"
            Ensure = "Present"
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        WindowsFeature FS
        {
            Name = "FS-FileServer"
            Ensure = "Present"
        }

        #Join domain
        Computer JoinDomain
        {
            Name       = $ComputerName
            DomainName = $DomainName
            Credential = $AdminCreds
        }

        # Add registry keys to avoid network interruptions
        Registry KeepAliveTimeRegistry
        {
            Ensure      = "Present"
            Key         = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            ValueName   = "KeepAliveTime"
            ValueData   = "120000"
            ValueType   = "Dword"
        }

        Registry KeepAliveIntervalRegistry
        {
            Ensure      = "Present"
            Key         = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            ValueName   = "KeepAliveInterval"
            ValueData   = "120000"
            ValueType   = "Dword"
        }

        #Set paging file size
        VirtualMemory PagingSettings
        {
            Type        = 'CustomSize'
            Drive       = $SwapDriveLetter
            InitialSize = $VirtualMemorySizeinMB
            MaximumSize = $VirtualMemorySizeinMB
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
