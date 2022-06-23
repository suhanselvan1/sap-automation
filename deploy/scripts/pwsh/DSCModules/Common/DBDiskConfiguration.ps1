Configuration DBDiskConfiguration
{

    param
    (
        [Parameter(Mandatory = $true)]
        [String[]]$DataDiskLUNNumbers,
        [Parameter(Mandatory = $true)]
        [String[]]$DataDiskDriveletters,
        [Parameter(Mandatory = $true)]
        [String]$LogDiskLUNNumber,
        [Parameter(Mandatory = $true)]
        [String]$LogDiskDriveletter,
        [Parameter(Mandatory = $true)]
        [String]$TempDBDiskLUNNumber,
        [Parameter(Mandatory = $true)]
        [String]$TempDBDiskDriveletter
        
    )

    Import-DscResource -ModuleName 'StorageDsc'

    $DiskList = Get-Disk | Where-Object -FilterScript {($_.DiskNumber -ne '0') -and ($_.DiskNumber -ne '1')}

    node localhost
    {
        $Count = 0

        # Initialize data disks
        foreach ($DataDiskLUNNumber in $DataDiskLUNNumbers) {

            $Count += 1

            foreach ($DiskListItem in $DiskList) {

                $DiskLocation = $DiskListItem.Location
                $DiskLun = $DiskLocation.split(' ')[-1]

                if ($DiskLun -eq $DataDiskLUNNumber) {

                    $FSLabel = 'Data'+$Count

                    Disk $FSLabel {

                        DiskId = $DiskListItem.UniqueId
                        DiskIdType = 'UniqueId'
                        PartitionStyle = 'GPT'
                        DriveLetter = $DataDiskDriveletters[$Count-1]
                        FSLabel = $FSLabel
                        AllocationUnitSize = 64KB
                        FSFormat = 'NTFS'

                    }

                }

            }

        }

        # Initialize log disk
        foreach ($DiskListItem in $DiskList) {

            $DiskLocation = $DiskListItem.Location
            $DiskLun = $DiskLocation.split(' ')[-1]

            if ($DiskLun -eq $LogDiskLUNNumber) {

                Disk Log {

                    DiskId = $DiskListItem.UniqueId
                    DiskIdType = 'UniqueId'
                    PartitionStyle = 'GPT'
                    DriveLetter = $LogDiskDriveletter
                    FSLabel = 'Log'
                    FSFormat = 'NTFS'

                }

            }

        }

        # Initialize temp DB disk
        foreach ($DiskListItem in $DiskList) {

            $DiskLocation = $DiskListItem.Location
            $DiskLun = $DiskLocation.split(' ')[-1]

            if ($DiskLun -eq $TempDBDiskLUNNumber) {

                Disk TempDB {

                    DiskId = $DiskListItem.UniqueId
                    DiskIdType = 'UniqueId'
                    PartitionStyle = 'GPT'
                    DriveLetter = $TempDBDiskDriveletter
                    FSLabel = 'TempDB'
                    FSFormat = 'NTFS'

                }

            }

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

DBDiskConfiguration -ConfigurationData $cd

Start-DscConfiguration DBDiskConfiguration -Wait -Verbose -Force
