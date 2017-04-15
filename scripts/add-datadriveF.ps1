configuration BuildSPTServers
{
    param
    (
        [Parameter(Mandatory)] [String]$driveletter,

		[Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
	)

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage

 node "localhost"
 {
         LocalConfigurationManager
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk ADDataDisk2
        {
            DiskNumber = 2
            DriveLetter = $driveletter
            FSLabel = 'Data'
			DependsOn = '[xWaitforDisk]Disk2'
         }
   }
}
