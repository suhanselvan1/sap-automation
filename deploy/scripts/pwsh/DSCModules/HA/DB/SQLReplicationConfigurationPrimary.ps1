Configuration SQLReplicaConfigurationPrimary
{

    param
    (

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $AdminCredential,

        [Parameter(Mandatory)]
        [String]$PrimaryClusterNodeName,

        [Parameter(Mandatory)]
        [String]$SID,

        [Parameter(Mandatory)]
        [String]$DBBackupPath,

        [Parameter(Mandatory)]
        [String]$AvailabilityGroupName
        
    )

    Import-DscResource -ModuleName 'SqlServerDsc'

    node localhost
    {
        # Add primary database to availability group and start replication
        SqlAGDatabase 'AddAGDatabaseMemberships'
        {
            AvailabilityGroupName   = $AvailabilityGroupName
            BackupPath              = $DBBackupPath
            DatabaseName            = $SID
            InstanceName            = 'MSSQLSERVER'
            ServerName              = $PrimaryClusterNodeName
            Ensure                  = 'Present'
            ProcessOnlyOnActiveNode = $true
            PsDscRunAsCredential    = $AdminCredential
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

SQLReplicaConfigurationPrimary -ConfigurationData $cd

Start-DscConfiguration SQLReplicaConfigurationPrimary -Wait -Verbose -Force
