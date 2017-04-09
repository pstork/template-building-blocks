Configuration ConfigureSptServer
{
    param (
        [Parameter(Mandatory)] [String]$DomainNetbiosName,
        [Parameter(Mandatory)] [String]$DomainFQDNName,

        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $FarmAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $SPSetupAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $WebPoolManagedAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $ServicePoolManagedAccount,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [PSCredential] $Passphrase,
        [Parameter(Mandatory=$true)] [ValidateNotNullorEmpty()] [String] $ServerRole,


        $DBAlias = "SqlTest",
        $serviceAppPoolName = "SharePoint Service Applications"
        $SuperUserAlias = "$DomainNetbiosName\sp_superuser"
        $SuperReaderAlias = "$DomainNetbiosName\sp_superreader"
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc

    [System.Management.Automation.PSCredential]$FarmAccountcred = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($FarmAccount.UserName)", $FarmAccount.Password)
    [System.Management.Automation.PSCredential]$SPSetupAccountcred = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SPSetupAccount.UserName)", $SPSetupAccount.Password)
    [System.Management.Automation.PSCredential]$WebPoolManagedAccountcred = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\amhraodap1", $WebPoolManagedAccount.Password)
    [System.Management.Automation.PSCredential]$ServicePoolManagedAccountcred = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($ServicePoolManagedAccount.UserName)", $ServicePoolManagedAccount.Password)
    [System.Management.Automation.PSCredential]$Passphrase = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Passphrase.UserName)", $Passphrase.Password)
    $ComputerName = $env:COMPUTERNAME

    node "localhost"
    {                #**********************************************************
        # Basic farm configuration
        #
        # This section creates the new SharePoint farm object, and
        # provisions generic services and components used by the
        # whole farm
        #**********************************************************
        SPCreateFarm CreateSPFarm
        {
 
            DatabaseServer           = $DBAlias
            FarmConfigDatabaseName   = "SP_Config_2016"
            Passphrase               = $Passphrase
            FarmAccount              = $FarmAccount
            PsDscRunAsCredential     = $SPSetupAccount
            AdminContentDatabaseName = "SP_AdminContent"
            #DependsOn                = "[SPInstall]InstallSharePoint"
            CentralAdministrationPort = "2016"
            ServerRole = $ServerRole


        }
        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $ServicePoolManagedAccount.UserName
            Account              = $ServicePoolManagedAccountcred
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $WebPoolManagedAccount.UserName
            Account              = $WebPoolManagedAccountcred
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings
        {
            PsDscRunAsCredential                        = $SPSetupAccountcred
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
            DatabaseName          = "SP_Usage"
            UsageLogCutTime       = 5
            UsageLogLocation      = "G:\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SPSetupAccountcred
            DependsOn                                   = "[SPManagedAccount]WebPoolManagedAccount"
#            DependsOn             = "[SPCreateFarm]CreateSPFarm"
        }
        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = "SP_State"
            PsDscRunAsCredential = $SPSetupAccountcred
           DependsOn             = "[SPManagedAccount]WebPoolManagedAccount"
#           DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
         #   DependsOn                                   = "[SPManagedAccount]WebPoolManagedAccount"
            DependsOn            = @('[SPCreateFarm]CreateSPFarm','[SPManagedAccount]ServicePoolManagedAccount')
        }

        #**********************************************************
        # Web applications
        #
        # This section creates the web applications in the 
        # SharePoint farm, as well as managed paths and other web
        # application settings
        #**********************************************************

        SPWebApplication SharePointSites
        {
            Name                   = "SharePoint Sites"
            ApplicationPool        = "SharePoint Sites"
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = "SP_Sites_Content"
            Url                    = "http://$ComputerName.$DomainFQDNName"
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccountcred
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }
        
        SPWebApplication OneDriveSites
        {
            Name                   = "OneDrive"
            ApplicationPool        = "SharePoint Sites"
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            AuthenticationMethod   = "NTLM"
            DatabaseName           = "SP_Sites_OneDrive"
            HostHeader             = "OneDrive.$DomainFQDNName"
            Url                    = "http://OneDrive.$DomainFQDNName"
            Port                   = 80
            PsDscRunAsCredential   = $SPSetupAccountcred
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }

        SPCacheAccounts WebAppCacheAccounts
        {
            WebAppUrl              = "http://$ComputerName.$DomainFQDNName"
            SuperUserAlias         = $SuperUserAlias
            SuperReaderAlias       = $SuperReaderAlias
            PsDscRunAsCredential   = $SPSetupAccountcred
            DependsOn              = "[SPWebApplication]SharePointSites"
        }

        SPCacheAccounts WebAppCacheAccounts
        {
            WebAppUrl              = "http://OneDrive.$DomainFQDNName"
            SuperUserAlias         = $SuperUserAlias
            SuperReaderAlias       = $SuperReaderAlias
            PsDscRunAsCredential   = $SPSetupAccountcred
            DependsOn              = "[SPWebApplication]OneDriveSites"
        }

        SPSite TeamSite
        {
            Url                      = "http://$ComputerName.$DomainFQDNName"
            OwnerAlias               = $SPSetupAccount.UserName
            Name                     = "Root Demo Site"
            Template                 = "STS#0"
            PsDscRunAsCredential     = $SPSetupAccountcred
            DependsOn                = "[SPWebApplication]SharePointSites"
        }

        SPSite MySiteHost
        {
            Url                      = "http://OneDrive.$DomainFQDNName"
            OwnerAlias               = $SPSetupAccount.UserName
            Name                     = "OneDrive"
            Template                 = "SPSMSITEHOST#0"
            PsDscRunAsCredential     = $SPSetupAccountcred
            DependsOn                = "[SPWebApplication]OneDriveSites"
        }

        #**********************************************************
        # Service instances
        #
        # This section describes which services should be running
        # and not running on the server
        #**********************************************************

        SPServiceInstance ClaimsToWindowsTokenServiceInstance
        {  
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
#            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }   

        SPServiceInstance SecureStoreServiceInstance
        {  
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
#            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        
        SPServiceInstance ManagedMetadataServiceInstance
        {  
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
#            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }

        SPServiceInstance BCSServiceInstance
        {  
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 
#            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        
        SPServiceInstance SearchServiceInstance
        {  
            Name                 = "SharePoint Server Search"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccountcred
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool" 

#            DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }
        
                
        #**********************************************************
        # Service applications
        #
        # This section creates service applications and required
        # dependencies
        #**********************************************************


        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $serviceAppPoolName
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccountcred
             DependsOn           = "[SPManagedAccount]WebPoolManagedAccount"
#           DependsOn            = "[SPCreateFarm]CreateSPFarm"
        }

        SPSecureStoreServiceApp SecureStoreServiceApp
        {
            Name                  = "Secure Store Service Application"
            ApplicationPool       = $serviceAppPoolName
            AuditingEnabled       = $true
            AuditlogMaxSize       = 30
            DatabaseName          = "SP_SecureStore"
            PsDscRunAsCredential  = $SPSetupAccountcred
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPServiceInstance]SecureStoreServiceInstance')
        }
        
        SPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {  
            Name                 = "Managed Metadata Service Application"
            PsDscRunAsCredential = $SPSetupAccountcred
            ApplicationPool      = $serviceAppPoolName
            DatabaseName         = "SP_MMS"
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPServiceInstance]ManagedMetadataServiceInstance')
        }

        SPBCSServiceApp BCSServiceApp
        {
            Name                  = "BCS Service Application"
            ApplicationPool       = $serviceAppPoolName
            DatabaseServer        = $DBAlias
            DatabaseName          = "SP_BCS"
            PsDscRunAsCredential  = $SPSetupAccountcred
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPSecureStoreServiceApp]SecureStoreServiceApp', '[SPServiceInstance]BCSServiceInstance')
        }

        SPSearchServiceApp SearchServiceApp
        {  
            Name                  = "Search Service Application"
            DatabaseName          = "SP_Search"
            ApplicationPool       = $serviceAppPoolName
            DefaultContentAccessAccount = $SPSetupAccount
            PsDscRunAsCredential  = $SPSetupAccountcred
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPServiceInstance]SearchServiceInstance')

        SPUserProfileServiceApp UserProfileApp
        {
            Name = "User Profile Service Application"
            ProfileDBName = "SP_Profile"
            ProfileDBServer = $DBAlias
            SocialDBName = "SP_Social"
            SocialDBServer = $DBAlias
            SyncDBName = "SP_Sync"
            SyncDBServer = $DBAlias
            FarmAccount = $FarmAccountcred
            ApplicationPool       = $serviceAppPoolName
            PsDscRunAsCredential  = $SPSetupAccountcred
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
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
        }
    }
}