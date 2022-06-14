Configuration SQLConfigurationSecondary
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $AdminCredential,

        [Parameter(Mandatory)]
        [String]$SecondaryClusterNodeName,

        [Parameter(Mandatory)]
        [String]$PrimaryClusterNodeName,

        [Parameter(Mandatory)]
        [String]$AvailabilityGroupName

    )

    Import-DscResource -ModuleName 'SqlServerDsc'

    Node localhost
    {

        # Adding the required service account to allow the cluster to log into SQL
        SqlLogin 'AddNTServiceClusSvc'
        {
            Ensure               = 'Present'
            Name                 = 'NT SERVICE\ClusSvc'
            LoginType            = 'WindowsUser'
            ServerName           = $SecondaryClusterNodeName
            InstanceName         = 'MSSQLSERVER'
        }

        # Add the required permissions to the cluster service login
        SqlPermission 'AddNTServiceClusSvcPermissions'
        {
            DependsOn            = '[SqlLogin]AddNTServiceClusSvc'
            Ensure               = 'Present'
            ServerName           = $SecondaryClusterNodeName
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
            ServerName           = $SecondaryClusterNodeName
            InstanceName         = 'MSSQLSERVER'
        }

        # Ensure the HADR option is enabled for the instance
        SqlAlwaysOnService EnableHADR
        {
            Ensure               = 'Present'
            InstanceName         = 'MSSQLSERVER'
            ServerName           = $SecondaryClusterNodeName
        }

        # Add the availability group replica to the availability group
        SqlAGReplica 'AddReplica'
        {
            Ensure                     = 'Present'
            Name                       = $SecondaryClusterNodeName
            AvailabilityGroupName      = $AvailabilityGroupName
            ServerName                 = $SecondaryClusterNodeName
            InstanceName               = 'MSSQLSERVER'
            PrimaryReplicaServerName   = $PrimaryClusterNodeName
            PrimaryReplicaInstanceName = 'MSSQLSERVER'
            ProcessOnlyOnActiveNode    = $true
	        FailoverMode               = 'Automatic'
	        AvailabilityMode	       = 'SynchronousCommit'
            PsDscRunAsCredential = $AdminCredential
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

SQLConfigurationSecondary -ConfigurationData $cd

Start-DscConfiguration SQLConfigurationSecondary -Wait -Verbose -Force
