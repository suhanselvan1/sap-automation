configuration ASCSInstanceConfiguration
{
    param
    (

        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,
        
        [Parameter(Mandatory)]
        [String]$ProfileDirectoryPath,

        [Parameter(Mandatory)]
        [String]$SID,

        [Parameter(Mandatory)]
        [String]$InstanceNumber,

        [Parameter(Mandatory)]
        [string]$ASCSClusterVirtualName,

	[Parameter(Mandatory)]
        [Int]$ProbePort

    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$($AdminCreds.UserName)@${DomainName}", $AdminCreds.Password)


    Node localhost
    {
        $SAPProfileFilePath = "${ProfileDirectoryPath}\${SID}_ASCS${InstanceNumber}_${ASCSClusterVirtualName}"

        Script ModifySAPProfile {
            SetScript            = "Add-Content $SAPProfileFilePath ""`nenque/encni/set_so_keepalive = true"""
            TestScript           = "if (Select-String -Path $SAPProfileFilePath -Pattern ""enque/encni/set_so_keepalive = true"") { `$true } else { `$false }"
            GetScript            = "@{Ensure = if (Test-Path -Path $SAPProfileFilePath -PathType Leaf) {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
        }

        $SAPIPResourceClusterParameters =  Get-ClusterResource "SAP $SID IP" | Get-ClusterParameter
        $OldProbePort = ($SAPIPResourceClusterParameters | Where-Object {$_.Name -eq "ProbePort" }).Value
        Script AddProbePort {
            SetScript            = "`$SAPClusterRoleName = ""SAP $SID""
            `$SAPIPresourceName = ""SAP $SID IP""
            `$SAPIPResourceClusterParameters =  Get-ClusterResource `$SAPIPresourceName | Get-ClusterParameter
            `$IPAddress = (`$SAPIPResourceClusterParameters | Where-Object {`$_.Name -eq ""Address"" }).Value
            `$NetworkName = (`$SAPIPResourceClusterParameters | Where-Object {`$_.Name -eq ""Network"" }).Value
            `$SubnetMask = (`$SAPIPResourceClusterParameters | Where-Object {`$_.Name -eq ""SubnetMask"" }).Value
            `$OverrideAddressMatch = (`$SAPIPResourceClusterParameters | Where-Object {`$_.Name -eq ""OverrideAddressMatch"" }).Value
            `$EnableDhcp = (`$SAPIPResourceClusterParameters | Where-Object {`$_.Name -eq ""EnableDhcp"" }).Value
            `$OldProbePort = (`$SAPIPResourceClusterParameters | Where-Object {`$_.Name -eq ""ProbePort"" }).Value
            `$var = Get-ClusterResource | Where-Object {  `$_.name -eq `$SAPIPresourceName  }
            Get-ClusterResource -Name `$SAPIPresourceName | Get-ClusterParameter
            `$var | Set-ClusterParameter -Multiple @{""Address""=`$IPAddress;""ProbePort""=$ProbePort;""Subnetmask""=`$SubnetMask;""Network""=`$NetworkName;""OverrideAddressMatch""=`$OverrideAddressMatch;""EnableDhcp""=`$EnableDhcp}
            Stop-ClusterResource -Name `$SAPIPresourceName
            sleep 5
            Start-ClusterGroup -Name `$SAPClusterRoleName
            Get-ClusterResource -Name `$SAPIPresourceName | Get-ClusterParameter"
            TestScript           = "if ($OldProbePort -eq ${ProbePort}) { `$true } else { `$false }"
            GetScript            = "@{Ensure = if ($OldProbePort) {'Present'} else {'Absent'}}"
            PsDscRunAsCredential = $DomainCreds
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



ASCSInstanceConfiguration -ConfigurationData $cd

Start-DscConfiguration ASCSInstanceConfiguration -Wait -Verbose -Force
