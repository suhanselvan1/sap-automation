Configuration UserConfiguration
{
    param
    (

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$DomainName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$UserName

    )

    Import-DSCResource -ModuleName SecurityPolicyDsc

    Node "localhost"
    {

        # Configure User Rights Management
        UserRightsAssignment UserRights1
        {
            Policy = 'Act_as_part_of_the_operating_system'
            Identity = $DomainName + "\" + $UserName
            Ensure = 'Present'
        }

        # Configure User Rights Management
        UserRightsAssignment UserRights2
        {
            Policy = 'Adjust_memory_quotas_for_a_process'
            Identity = $DomainName + "\" + $UserName
            Ensure = 'Present'
        }

        # Configure User Rights Management
        UserRightsAssignment UserRights3
        {
            Policy = 'Replace_a_process_level_token'
            Identity = $DomainName + "\" + $UserName
            Ensure = 'Present'
        }
    }
}

$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
        }
    )
}

UserConfiguration -ConfigurationData $cd

Start-DscConfiguration UserConfiguration -Wait -Verbose -Force
