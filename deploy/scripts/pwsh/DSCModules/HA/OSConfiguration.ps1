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
        [string[]]$ExclusionPaths,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$VirtualMemorySizeinMB

    )
    
    Import-DSCResource -ModuleName NetworkingDsc, ComputerManagementDsc, PSDesiredStateConfiguration, WindowsDefender

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

        #Set paging file size
        VirtualMemory PagingSettings
        {
            Type        = 'CustomSize'
            Drive       = $SwapDriveLetter
            InitialSize = $VirtualMemorySizeinMB
            MaximumSize = $VirtualMemorySizeinMB
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
        ExclusionPath = $ExclusionPaths
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
