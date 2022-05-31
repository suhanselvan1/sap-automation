param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$MediaPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$ParameterFilePath,

	[Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$ProductID
    )

$InstallCommand = "$MediaPath SAPINST_INPUT_PARAMETERS_URL=$ParameterFilePath SAPINST_EXECUTE_PRODUCT_ID=$ProductID SAPINST_SKIP_DIALOGS=true SAPINST_START_GUI=false SAPINST_START_GUISERVER=false"

Invoke-Expression -Command $InstallCommand
