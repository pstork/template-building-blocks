configuration ConfigureSPServers
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

	Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory, xCredSSP, SharePointDsc

    $RebootVirtualMachine = $false
	$PSDscAllowDomainUser = $true
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

        xCredSSP CredSSPServer 
        { 
            Ensure = "Present"
            Role = "Server"
        } 
       
        xCredSSP CredSSPClient 
        { 
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = "*.$DomainFQDNName"
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
             DependsOn           = "[SPManagedAccount]ServicePoolManagedAccount"
        }
		
        #**********************************************************
        # Service instances
        #
        # This section describes which services should be running
        # and not running on the server
        #**********************************************************


            SPServiceInstance AppManagementServiceInstance
            {  
                Name                 = "App Management Service"
                Ensure               = "Present"
                PsDscRunAsCredential = $SPSetupAccountCreds
                DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
            }
            SPServiceInstance ManagedMetadataServiceInstance
            {  
                Name                 = "Managed Metadata Web Service"
                Ensure               = "Present"
                PsDscRunAsCredential = $SPSetupAccountCreds
                DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
            }
            SPServiceInstance SubscriptionSettingsServiceInstance
            {  
                Name                 = "Microsoft SharePoint Foundation Subscription Settings Service"
                Ensure               = "Present"
                PsDscRunAsCredential = $SPSetupAccountcreds
                DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
            }
            SPServiceInstance UserProfileServiceInstance
            {  
                Name                 = "User Profile Service"
                Ensure               = "Present"
                PsDscRunAsCredential = $SPSetupAccountcreds
                DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
            }

        #**********************************************************
        # Service applications
        #
        # This section creates service applications and required
        # dependencies
        #**********************************************************

             SPAppManagementServiceApp AppManagementServiceApp
            {
                Name                 = "App Management Service Application"
                ApplicationPool      = $serviceAppPoolName
                DatabaseName         = "SP2016_AppManagement"
                PsDscRunAsCredential = $SPSetupAccountcreds  
                DependsOn            = '[SPServiceAppPool]MainServiceAppPool'      
            }

            SPSubscriptionSettingsServiceApp SubscriptionSettingsServiceApp
            {
                Name                 = "Subscription Settings Service Application"
                ApplicationPool      = $serviceAppPoolName
                DatabaseName         = "SP2016_SubscriptionSettings"
                PsDscRunAsCredential = $SPSetupAccountcreds
                DependsOn            = '[SPServiceAppPool]MainServiceAppPool'      
            }
 
            SPManagedMetaDataServiceApp ManagedMetadataServiceApp
            {  
                Name                 = "Managed Metadata Service Application"
                PsDscRunAsCredential = $SPSetupAccountcreds
                ApplicationPool      = $serviceAppPoolName
                DatabaseName         = "SP2016_MMS"
                DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPServiceInstance]ManagedMetadataServiceInstance')
            }


            SPUserProfileServiceApp UserProfileApp
            {
                Name = "User Profile Service Application"
                ProfileDBName = "SP2016_Profile"
                ProfileDBServer = $DBAlias
                SocialDBName = "SP2016_Social"
                SocialDBServer = $DBAlias
                SyncDBName = "SP2016_Sync"
                SyncDBServer = $DBAlias
                MySiteHostLocation = "http://OneDrive.$DomainFQDNName"
                FarmAccount = $FarmAccountcred
                ApplicationPool       = $serviceAppPoolName
                PsDscRunAsCredential  = $SPSetupAccountcreds
                DependsOn             = '[SPServiceAppPool]MainServiceAppPool'
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