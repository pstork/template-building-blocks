configuration ConfigureFarm
{
	param
    (
		[Parameter(Mandatory)]
        [String]$domainName,
		
        [Parameter(Mandatory)]
        [String]$DomainFQDNName,
		
        [Parameter(Mandatory)]
        [String]$SqlAlwaysOnEndpointName,
		
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
		
        [String] $SuperUserAlias = "sp_superuser",
        [String] $SuperReaderAlias = "sp_superreader",
        [string]$webAppPoolName = "SharePoint Sites",
        [string]$serviceAppPoolName = "Service App Pool",
        

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
	)
	
	Import-DscResource -ModuleName xActiveDirectory, SharePointDsc, PSDesiredStateConfiguration
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

        xADUser SPSuperUser
        {
            DomainName 						= $domainName
            UserName 						= $SuperUserAlias
            DisplayName 					= "SuperUser Cache Account"
            PasswordNeverExpires 			= $true            
            Ensure 							= 'Present'
            Password 						= $Passphrase
            DomainAdministratorCredential 	= $SPSetupAccountCreds
			DependsOn                 		= "[WindowsFeature]ADPowerShell"
        }

        xADUser SPSuperReader
        {
            DomainName 						= $domainName
            UserName 						= $SuperReaderAlias
            DisplayName 					= "SuperReader Cache Account"
            PasswordNeverExpires 			= $true            
            Ensure 							= 'Present'
            Password 						= $Passphrase
            DomainAdministratorCredential 	= $SPSetupAccountCreds
			DependsOn                 		= "[WindowsFeature]ADPowerShell"
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
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccountCreds
             DependsOn           = "[SPManagedAccount]WebPoolManagedAccount"
        }
		
        SPWebApplication SharePointSites
        {
            Name                   = "SharePoint Sites"
            ApplicationPool        = $webAppPoolName
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = "SP2016_Sites_Content"
            Url                    = "http://Portal.$DomainFQDNName"
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccountCreds
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }
        
        SPWebApplication OneDriveSites
        {
            Name                   = "OneDrive"
            ApplicationPool        = $webAppPoolName
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = "SP2016_Sites_OneDrive"
            HostHeader             = "OneDrive.$DomainFQDNName"
            Url                    = "http://OneDrive.$DomainFQDNName"
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccountCreds
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }

        SPCacheAccounts WebAppCacheAccounts
        {
            WebAppUrl              = "http://Portal.$DomainFQDNName"
            SuperUserAlias         = "${DomainName}\$($SuperUserAlias)"
            SuperReaderAlias       = "${DomainName}\$($SuperReaderAlias)"
            PsDscRunAsCredential   = $SPSetupAccountCreds
            DependsOn              = "[SPWebApplication]SharePointSites"
        }

        SPCacheAccounts OneDriveCacheAccounts
        {
            WebAppUrl              = "http://OneDrive.$DomainFQDNName"
            SuperUserAlias         = "${DomainName}\$($SuperUserAlias)"
            SuperReaderAlias       = "${DomainName}\$($SuperReaderAlias)"
            PsDscRunAsCredential   = $SPSetupAccountCreds
            DependsOn              = "[SPWebApplication]OneDriveSites"
        }

        SPSite TeamSite
        {
            Url                      = "http://Portal.$DomainFQDNName"
            OwnerAlias               = $SPSetupAccount.UserName
            Name                     = "Root Demo Site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupAccountCreds
            DependsOn                = "[SPWebApplication]SharePointSites"
        }

        SPSite MySiteHost
        {
            Url                      = "http://OneDrive.$DomainFQDNName"
            OwnerAlias               = $SPSetupAccount.UserName
            Name                     = "OneDrive"
            Template                 = "SPSMSITEHOST#0"
            PsDscRunAsCredential     = $SPSetupAccountCreds
            DependsOn                = "[SPWebApplication]OneDriveSites"
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
			PsDscRunAsCredential = $SPSetupAccountCreds
			DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
		}
		SPServiceInstance UserProfileServiceInstance
		{  
			Name                 = "User Profile Service"
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

		 SPAppManagementServiceApp AppManagementServiceApp
		{
			Name                 = "App Management Service Application"
			ApplicationPool      = $serviceAppPoolName
			DatabaseName         = "SP2016_AppManagement"
			PsDscRunAsCredential = $SPSetupAccountCreds  
			DependsOn            = '[SPServiceAppPool]MainServiceAppPool'      
		}

		SPSubscriptionSettingsServiceApp SubscriptionSettingsServiceApp
		{
			Name                 = "Subscription Settings Service Application"
			ApplicationPool      = $serviceAppPoolName
			DatabaseName         = "SP2016_SubscriptionSettings"
			PsDscRunAsCredential = $SPSetupAccountCreds
			DependsOn            = '[SPServiceAppPool]MainServiceAppPool'      
		}
		SPManagedMetaDataServiceApp ManagedMetadataServiceApp
		{  
			Name                 = "Managed Metadata Service Application"
			PsDscRunAsCredential = $SPSetupAccountCreds
			ApplicationPool      = $serviceAppPoolName
			DatabaseName         = "SP2016_MMS"
			DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPServiceInstance]ManagedMetadataServiceInstance')
		}

		SPUserProfileServiceApp UserProfileApp
		{
			Name = "User Profile Service Application"
			ProfileDBName = "SP2016_Profile"
			ProfileDBServer = $SqlAlwaysOnEndpointName
			SocialDBName = "SP2016_Social"
			SocialDBServer = $SqlAlwaysOnEndpointName
			SyncDBName = "SP2016_Sync"
			SyncDBServer = $SqlAlwaysOnEndpointName
			MySiteHostLocation = "http://OneDrive.$DomainFQDNName"
			FarmAccount  =  $FarmAccountCreds
			ApplicationPool       = $serviceAppPoolName
			PsDscRunAsCredential  = $SPSetupAccountCreds
			DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPSite]MySiteHost')
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