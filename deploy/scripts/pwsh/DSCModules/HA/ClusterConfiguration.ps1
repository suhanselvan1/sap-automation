configuration ConfigureCluster
{
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [String]$ClusterName,

        [Parameter(Mandatory)]
        [String]$NamePrefix,

        [Parameter(Mandatory)]
        [Int]$VMCount,

        [Parameter(Mandatory)]
        [String]$WitnessType,

	[Parameter(Mandatory)]
        [String]$ListenerIPAddress,

	[Parameter(Mandatory)]
        [Int]$ListenerProbePort1,

	[Parameter(Mandatory)]
        [Int]$ListenerProbePort2,

	[Parameter(Mandatory)]
        [String]$WitnessStorageName,

	[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$WitnessStorageKey
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, ComputerManagementDsc

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$($AdminCreds.UserName)@${DomainName}", $AdminCreds.Password)

    Node localhost
    {

        Script CreateCluster {
            SetScript            = "If ('${ListenerIPAddress}' -ne '0.0.0.0') { New-Cluster -Name ${ClusterName} -Node ${env:COMPUTERNAME} -NoStorage -StaticAddress ${ListenerIPAddress} } else { New-Cluster -Name ${ClusterName} -Node ${env:COMPUTERNAME} -NoStorage }"
            TestScript           = "(Get-Cluster -ErrorAction SilentlyContinue).Name -eq '${ClusterName}'"
            GetScript            = "@{Ensure = if ((Get-Cluster -ErrorAction SilentlyContinue).Name -eq '${ClusterName}') {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
        }

        Script ClusterIPAddress {
            SetScript  = "Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue | Get-ClusterResource | Where-Object ResourceType -eq 'IP Address' -ErrorAction SilentlyContinue | Set-ClusterParameter -Name ProbePort ${ListenerProbePort2}; `$global:DSCMachineStatus = 1"
            TestScript = "if ('${ListenerIpAddress}' -eq '0.0.0.0') { `$true } else { (Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue | Get-ClusterResource | Where-Object ResourceType -eq 'IP Address' -ErrorAction SilentlyContinue | Get-ClusterParameter -Name ProbePort).Value -eq ${ListenerProbePort2}}"
            GetScript  = "@{Ensure = if ('${ListenerIpAddress}' -eq '0.0.0.0') { 'Present' } elseif ((Get-ClusterGroup -Name 'Cluster Group' -ErrorAction SilentlyContinue | Get-ClusterResource | Where-Object ResourceType -eq 'IP Address' -ErrorAction SilentlyContinue | Get-ClusterParameter -Name ProbePort).Value -eq ${ListenerProbePort2}) {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
            DependsOn  = "[Script]CreateCluster"
        }

        for ($count = 1; $count -lt $VMCount; $count++) {
            Script "AddClusterNode_${count}" {
                SetScript            = "Add-ClusterNode -Name ${NamePrefix}-AppVM${count} -NoStorage"
                TestScript           = "'${NamePrefix}-AppVM${count}' -in (Get-ClusterNode).Name"
                GetScript            = "@{Ensure = if ('${NamePrefix}-AppVM${count}' -in (Get-ClusterNode).Name) {'Present'} else {'Absent'}}"
                PsDscRunAsCredential = $DomainCreds
                DependsOn            = "[Script]ClusterIPAddress"
            }
        }

        Script ClusterWitness {
            SetScript  = "if ('${WitnessType}' -eq 'Cloud') { Set-ClusterQuorum -CloudWitness -AccountName ${WitnessStorageName} -AccessKey $($WitnessStorageKey.GetNetworkCredential().Password) } else { Set-ClusterQuorum -DiskWitness `$((Get-ClusterGroup -Name 'Available Storage' | Get-ClusterResource | ? ResourceType -eq 'Physical Disk' | Sort-Object Name | Select-Object -Last 1).Name) }"
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
            SetScript  = "Remove-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -Profile Domain -Direction Inbound -Action Allow -Enabled True -Protocol 'tcp' -LocalPort ${ListenerProbePort1}"
            TestScript = "(Get-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq ${ListenerProbePort1}"
            GetScript  = "@{Ensure = if ((Get-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 1' -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq ${ListenerProbePort1}) {'Present'} else {'Absent'}}"
            DependsOn  = "[Script]IncreaseClusterTimeouts"
        }

        Script FirewallRuleProbePort2 {
            SetScript  = "Remove-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 2' -ErrorAction SilentlyContinue; New-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 2' -Profile Domain -Direction Inbound -Action Allow -Enabled True -Protocol 'tcp' -LocalPort ${ListenerProbePort2}"
            TestScript = "(Get-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 2' -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq ${ListenerProbePort2}"
            GetScript  = "@{Ensure = if ((Get-NetFirewallRule -DisplayName 'Failover Cluster - Probe Port 2' -ErrorAction SilentlyContinue | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue).LocalPort -eq ${ListenerProbePort2}) {'Present'} else {'Absent'}}"
            DependsOn  = "[Script]FirewallRuleProbePort1"
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

ConfigureCluster -ConfigurationData $cd

Start-DscConfiguration ConfigureCluster -Wait -Verbose -Force
