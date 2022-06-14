param
    (
	[Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$BinPath
    )

$SQLCorePath = "$Binpath\SQL4SAP.Core.exe"
$SQLInstall = "'' | & $SQLCorePath"
Invoke-Expression -Command $SQLInstall
