configuration ConfigureFarm
{
	param
    (
		[Parameter(Mandatory)]
        [String]$domainName,
		
        [Parameter(Mandatory)]
        [String]$DomainFQDNName,
		
		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Passphrase,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$FarmAccount,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetupAccount,
		
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ServicePoolManagedAccount,
		
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$WebPoolManagedAccount,
		
        [string]$serviceAppPoolName = "Service App Pool",

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
	)
	
	Import-DscResource -ModuleName xActiveDirectory, SharePointDsc
 #   [System.Management.Automation.PSCredential]$PassphraseCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Passphrase.UserName)", $Passphrase.Password)
    [System.Management.Automation.PSCredential]$FarmAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($FarmAccount.UserName)", $FarmAccount.Password)
    [System.Management.Automation.PSCredential]$SPSetupAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SPSetupAccount.UserName)", $SPSetupAccount.Password) 
    [System.Management.Automation.PSCredential]$ServicePoolManagedAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($ServicePoolManagedAccount.UserName)", $ServicePoolManagedAccount.Password) 
    [System.Management.Automation.PSCredential]$WebPoolManagedAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($WebPoolManagedAccount.UserName)", $WebPoolManagedAccount.Password) 

	Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory, SharePointDsc

    $RebootVirtualMachine = $false
	$PSDscAllowDomainUser = $true
$env:COMPUTERNAME
    if ($DomainName)
    {
        $RebootVirtualMachine = $true
    }
	node "localhost"
    {
		WindowsFeature ADPowerShell
		{
			Ensure = "Present"
			Name = "RSAT-AD-PowerShell"
		}
	
       xADUser ServicePoolManagedAccount
        {
            DomainName 						= $domainName
            UserName 						= $ServicePoolManagedAccount.UserName
            DisplayName 					= "Service Pool Account"
            PasswordNeverExpires 			= $true            
            Ensure 							= "Present"
            Password 						= $ServicePoolManagedAccount
            DomainAdministratorCredential 	= $SPSetupAccountCreds
			DependsOn                 		= "[WindowsFeature]ADPowerShell"
        }		

        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $ServicePoolManagedAccountCreds.UserName
            Account              = $ServicePoolManagedAccountCreds
            PsDscRunAsCredential = $SPSetupAccountCreds
            Ensure               = 'Present'
            DependsOn            = "[xADUser]ServicePoolManagedAccount"
        }

        xADUser WebPoolManagedAccount
        {
            DomainName 						= $domainName
            UserName 						= $WebPoolManagedAccount.UserName
            DisplayName 					= "Web App Pool Account"
            PasswordNeverExpires 			= $true            
            Ensure 							= "Present"
            Password 						= $WebPoolManagedAccount
            DomainAdministratorCredential 	= $SPSetupAccountCreds
			DependsOn                 		= "[SPManagedAccount]ServicePoolManagedAccount"
        }		

        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $WebPoolManagedAccountCreds.UserName
            Account              = $WebPoolManagedAccountCreds
            Ensure               = 'Present'
            PsDscRunAsCredential = $SPSetupAccountCreds
            DependsOn            = "[xADUser]WebPoolManagedAccount"
        }

        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            PsDscRunAsCredential                        = $SPSetupAccountCreds
            LogPath                                     = "G:\ULS"
            LogSpaceInGB                                = 5
            AppAnalyticsAutomaticUploadEnabled          = $false
            CustomerExperienceImprovementProgramEnabled = $true
            DaysToKeepLogs                              = 7
            DownloadErrorReportingUpdatesEnabled        = $false
            ErrorReportingAutomaticUploadEnabled        = $false
            ErrorReportingEnabled                       = $false
            EventLogFloodProtectionEnabled              = $true
            EventLogFloodProtectionNotifyInterval       = 5
            EventLogFloodProtectionQuietPeriod          = 2
            EventLogFloodProtectionThreshold            = 5
            EventLogFloodProtectionTriggerPeriod        = 2
            LogCutInterval                              = 15
            LogMaxDiskSpaceUsageEnabled                 = $true
            ScriptErrorReportingDelay                   = 30
            ScriptErrorReportingEnabled                 = $true
            ScriptErrorReportingRequireAuth             = $true
            DependsOn                                   = "[SPManagedAccount]WebPoolManagedAccount"
        }
 
        SPUsageApplication UsageApplication 
        {
            Name                  = "Usage Service Application"
            DatabaseName          = "SP2016_Usage"
            UsageLogCutTime       = 5
            UsageLogLocation      = "G:\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SPSetupAccountCreds
            DependsOn             = "[SPManagedAccount]WebPoolManagedAccount"
#            DependsOn             = "[SPFarmAdministrators]AddFarmAdmins"
        }

        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = "SP2016_State"
            PsDscRunAsCredential = $SPSetupAccountCreds
           DependsOn             = "[SPManagedAccount]WebPoolManagedAccount"
#           DependsOn            = "[SPFarmAdministrators]AddFarmAdmins"
        }

        #**********************************************************
        # Web applications
        #
        # This section creates the web applications in the 
        # SharePoint farm, as well as managed paths and other web
        # application settings
        #**********************************************************

        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $serviceAppPoolName
            ServiceAccount       = $ServicePoolManagedAccountCreds.UserName
            PsDscRunAsCredential = $SPSetupAccountCreds
             DependsOn           = "[SPManagedAccount]WebPoolManagedAccount"
        }

        #**********************************************************
        # Service instances
        #
        # This section describes which services should be running
        # and not running on the server
        #**********************************************************

        SPServiceInstance SearchServiceInstance
		{  
			Name                 = "SharePoint Server Search"
			Ensure               = "Present"
			PsDscRunAsCredential = $SPSetupAccountCreds
			DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
		}

        #**********************************************************
        # Service applications
        #
        # This section creates service applications and required
        # dependencies
        #**********************************************************

        SPSearchServiceApp SearchServiceApp
		{  
			Name                  = "Search Service Application"
			Ensure                = "Present"
			DatabaseName          = "SP2016_Search"
			ApplicationPool       = $serviceAppPoolName
			DefaultContentAccessAccount = $SPSetupAccountCreds
			PsDscRunAsCredential  = $SPSetupAccountCreds
			DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPServiceInstance]SearchServiceInstance')
		}        
		SPSearchTopology LocalSearchTopology
		{
			ServiceAppName          = "Search Service Application"
			Admin                   = $env:COMPUTERNAME
			Crawler                 = $env:COMPUTERNAME
			ContentProcessing       = $env:COMPUTERNAME
			AnalyticsProcessing     = $env:COMPUTERNAME
			QueryProcessing         = $env:COMPUTERNAME
			PsDscRunAsCredential    = $SPSetupAccountCreds
			FirstPartitionDirectory = "F:\SearchIndexes\0"
			IndexPartition          = $env:COMPUTERNAME
			DependsOn               = "[SPSearchServiceApp]SearchServiceApp"
		}

        #**********************************************************
        # Local configuration manager settings
        #
        # This section contains settings for the LCM of the host
        # that this configuraiton is applied to
        #**********************************************************
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = 'ApplyOnly'

        }
	}
}