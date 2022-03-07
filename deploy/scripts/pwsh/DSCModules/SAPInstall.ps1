Configuration SAPInstall
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Node localhost
    {
        Script ScriptExample
        {
            SetScript = { M:\SWPM\sapinst SAPINST_INPUT_PARAMETERS_URL=C:\Users\azureadm\Desktop\inifile.params SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_CI:NW750.MSS.ABAP SAPINST_SKIP_DIALOGS=true SAPINST_START_GUI=false SAPINST_START_GUISERVER=false }
            TestScript = { return $True }
            GetScript = { return $True }
        }
    }
}

SAPInstall

Start-DscConfiguration SAPInstall -Wait -Verbose -Force
