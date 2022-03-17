Configuration SAPInstall
{

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$MediaPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$ParameterFilePath
    )

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    $InstallCommand = "$MediaPath SAPINST_INPUT_PARAMETERS_URL=$ParameterFilePath SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_CI:NW750.MSS.ABAP SAPINST_SKIP_DIALOGS=true SAPINST_START_GUI=false SAPINST_START_GUISERVER=false"

    Node localhost
    {
        Script ScriptExample
        {
            SetScript = { $InstallCommand }
            TestScript = { return $False }
            GetScript = { return $True }
        }
    }
}

SAPInstall

Start-DscConfiguration SAPInstall -Wait -Verbose -Force
