param
    (
	[Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$BinPath
    )

$SQLClientInstall = "MSIEXEC.EXE /I $BinPath\msodbcsql.msi /qb IACCEPTMSODBCSQLLICENSETERMS=YES"
Invoke-Expression -Command $SQLClientInstall
