configuration ClusterConfiguration
{
    param
    (

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$ClusterName,

        [Parameter(Mandatory)]
        [string[]]$ClusterNodeNames,

	[Parameter(Mandatory)]
        [String]$ListenerIPAddress,

	[Parameter(Mandatory)]
        [Int]$ListenerProbePort,

	[Parameter(Mandatory)]
        [String]$WitnessStorageName,

	[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$WitnessStorageKey
        
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$($AdminCreds.UserName)@${DomainName}", $AdminCreds.Password)

    $ComputerInfo = Get-ComputerInfo

    $WindowsVersion = $ComputerInfo.WindowsProductName

    $CurrentClusterNode = $ClusterNodeNames[0]

    Node localhost
    {

        Script CreateCluster {
            SetScript            = "If ('${WindowsVersion}' -ne 'Windows Server 2019 Datacenter') { New-Cluster -Name ${ClusterName} -Node ${CurrentClusterNode} -NoStorage -StaticAddress ${ListenerIPAddress} } else { New-Cluster -Name ${ClusterName} -Node ${CurrentClusterNode} -NoStorage }"
            TestScript           = "(Get-Cluster -ErrorAction SilentlyContinue).Name -eq '${ClusterName}'"
            GetScript            = "@{Ensure = if ((Get-Cluster -ErrorAction SilentlyContinue).Name -eq '${ClusterName}') {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
        }

        Script ClusterIPAddress {
            SetScript  = "Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue | Get-ClusterResource | Where-Object ResourceType -eq 'IP Address' -ErrorAction SilentlyContinue | Set-ClusterParameter -Name ProbePort ${ListenerProbePort}; `$global:DSCMachineStatus = 1"
            TestScript = "if ('${WindowsVersion}' -ne 'Windows Server 2019 Datacenter') { `$true } else { (Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue | Get-ClusterResource | Where-Object ResourceType -eq 'IP Address' -ErrorAction SilentlyContinue | Get-ClusterParameter -Name ProbePort).Value -eq ${ListenerProbePort}}"
            GetScript  = "@{Ensure = if ('${WindowsVersion}' -ne 'Windows Server 2019 Datacenter') { 'Present' } elseif ((Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue | Get-ClusterResource | Where-Object ResourceType -eq 'IP Address' -ErrorAction SilentlyContinue | Get-ClusterParameter -Name ProbePort).Value -eq ${ListenerProbePort}) {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
            DependsOn  = "[Script]CreateCluster"
        }

        for ($count = 1; $count -lt $ClusterNodeNames.count; $count++) {
            $NodeName = $ClusterNodeNames[$count]
            Script "AddClusterNode_${count}" {
                SetScript            = "Add-ClusterNode -Name ${NodeName} -NoStorage"
                TestScript           = "'${NodeName}' -in (Get-ClusterNode).Name"
                GetScript            = "@{Ensure = if ('${NodeName}' -in (Get-ClusterNode).Name) {'Present'} else {'Absent'}}"
                PsDscRunAsCredential = $DomainCreds
                DependsOn            = "[Script]ClusterIPAddress"
            }
        }

        Script ClusterWitness {
            SetScript  = "Set-ClusterQuorum -CloudWitness -AccountName ${WitnessStorageName} -AccessKey $($WitnessStorageKey.GetNetworkCredential().Password)"
            TestScript = "((Get-ClusterQuorum).QuorumResource).Count -gt 0"
            GetScript  = "@{Ensure = if (((Get-ClusterQuorum).QuorumResource).Count -gt 0) {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
        }

        Script IncreaseClusterTimeouts {
            SetScript  = "(Get-Cluster).SameSubnetDelay = 2000; (Get-Cluster).SameSubnetThreshold = 15; (Get-Cluster).CrossSubnetDelay = 3000; (Get-Cluster).CrossSubnetThreshold = 15"
            TestScript = "(Get-Cluster).SameSubnetDelay -eq 2000 -and (Get-Cluster).SameSubnetThreshold -eq 15 -and (Get-Cluster).CrossSubnetDelay -eq 3000 -and (Get-Cluster).CrossSubnetThreshold -eq 15"
            GetScript  = "@{Ensure = if ((Get-Cluster).SameSubnetDelay -eq 2000 -and (Get-Cluster).SameSubnetThreshold -eq 15 -and (Get-Cluster).CrossSubnetDelay -eq 3000 -and (Get-Cluster).CrossSubnetThreshold -eq 15) {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
            DependsOn  = "[Script]ClusterWitness"
        }
             
        Script FirewallRuleProbePort1 {
            SetScript  = "Remove-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -Profile Domain -Direction Inbound -Action Allow -Enabled True -Protocol 'tcp' -LocalPort ${ListenerProbePort}"
            TestScript = "(Get-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq ${ListenerProbePort}"
            GetScript  = "@{Ensure = if ((Get-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq ${ListenerProbePort}) {'Present'} else {'Absent'}}"
            DependsOn  = "[Script]IncreaseClusterTimeouts"
        }

        LocalConfigurationManager {
            ActionAfterReboot = "ContinueConfiguration"
            ConfigurationMode = "ApplyAndMonitor"
            RebootNodeIfNeeded = $True
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

ClusterConfiguration -ConfigurationData $cd

Start-DscConfiguration ClusterConfiguration -Wait -Verbose -Force
