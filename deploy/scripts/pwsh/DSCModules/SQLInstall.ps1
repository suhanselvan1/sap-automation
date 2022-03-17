Configuration SQLInstall
{

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$DestPath
    )

     Import-DscResource -ModuleName SqlServerDsc

     node localhost
     {
          #Install .Net 4.5       
          WindowsFeature 'NetFramework45'
          {
               Name   = 'NET-Framework-45-Core'
               Ensure = 'Present'
          }

          #Install SQL Server
          SqlSetup 'InstallDefaultInstance'
          {
               InstanceName        = 'MSSQLSERVER'
               Features            = 'SQLENGINE'
               SourcePath          = $SourcePath
               SQLSysAdminAccounts = @('Administrators')
               DependsOn           = '[WindowsFeature]NetFramework45'
          }
     }
}

SQLInstall

Start-DscConfiguration -Path $DestPath -Wait -Force -Verbose