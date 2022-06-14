Configuration SQLConfigurationPrimary
{

    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $AdminCredential,

        [Parameter(Mandatory)]
        [String]$PrimaryClusterNodeName,

        [Parameter(Mandatory)]
        [String]$AvailabilityGroupName,

        [Parameter(Mandatory)]
        [String]$ClusterName,

        [Parameter(Mandatory)]
        [String]$ListenerIPAddress,

        [Parameter(Mandatory)]
        [Int]$ListenerPort
        
    )

    Import-DscResource -ModuleName 'SqlServerDsc'

    node localhost
    {

        # Adding the required service account to allow the cluster to log into SQL
        SqlLogin 'AddNTServiceClusSvc'
        {
            Ensure               = 'Present'
            Name                 = 'NT SERVICE\ClusSvc'
            LoginType            = 'WindowsUser'
            ServerName           = $PrimaryClusterNodeName
            InstanceName         = 'MSSQLSERVER'
        }

        # Add the required permissions to the cluster service login
        SqlPermission 'AddNTServiceClusSvcPermissions'
        {
            DependsOn            = '[SqlLogin]AddNTServiceClusSvc'
            Ensure               = 'Present'
            ServerName           = $PrimaryClusterNodeName
            InstanceName         = 'MSSQLSERVER'
            Principal            = 'NT SERVICE\ClusSvc'
            Permission           = 'AlterAnyAvailabilityGroup', 'ViewServerState'
        }

        # Create a DatabaseMirroring endpoint
        SqlEndpoint 'HADREndpoint'
        {
            EndPointName         = 'HADR'
            EndpointType         = 'DatabaseMirroring'
            Ensure               = 'Present'
            Port                 = 5022
            ServerName           = $PrimaryClusterNodeName
            InstanceName         = 'MSSQLSERVER'
        }

        # Ensure the HADR option is enabled for the instance
        SqlAlwaysOnService 'EnableHADR'
        {
            Ensure               = 'Present'
            InstanceName         = 'MSSQLSERVER'
            ServerName           = $PrimaryClusterNodeName
            RestartTimeout       = 120
        }

        # Create the availability group on the instance tagged as the primary replica
        SqlAG 'AddTestAG'
        {
            Ensure                     = 'Present'
            Name                       = $AvailabilityGroupName
            InstanceName               = 'MSSQLSERVER'
            ServerName                 = $PrimaryClusterNodeName
            ProcessOnlyOnActiveNode    = $true
	        FailoverMode               = 'Automatic'
	        AvailabilityMode	       = 'SynchronousCommit'
            DependsOn                  = '[SqlAlwaysOnService]EnableHADR', '[SqlEndpoint]HADREndpoint', '[SqlPermission]AddNTServiceClusSvcPermissions'
        }

        # Create the availability group listener
        SqlAGListener 'AvailabilityGroupListener'
        {
            Ensure               = 'Present'
            ServerName           = $PrimaryClusterNodeName
            InstanceName         = 'MSSQLSERVER'
            AvailabilityGroup    = $AvailabilityGroupName
            Name                 = $AvailabilityGroupName+'Listener'
            IpAddress            = $ListenerIPAddress
            Port                 = $ListenerPort
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

SQLConfigurationPrimary -ConfigurationData $cd

Start-DscConfiguration SQLConfigurationPrimary -Wait -Verbose -Force
