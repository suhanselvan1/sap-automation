param
    (
	[Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$ExePath
    )

$Script = "$ExePath\VC_redist.x64.exe /S /v/qn"
Invoke-Expression -Command $Script
