configuration CreateJoinFarm
{
	param
    (
		[Parameter(Mandatory)]
        [String]$domainName,
		
        [Parameter(Mandatory)]
        [String]$SqlAlwaysOnEndpointName,
		
		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Passphrase,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$FarmAccount,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SPSetupAccount,
		
		[Parameter(Mandatory)]
        [String]$ServerRole,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
	)
	
	Import-DscResource -ModuleName xActiveDirectory, SharePointDsc
 #   [System.Management.Automation.PSCredential]$PassphraseCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Passphrase.UserName)", $Passphrase.Password)
    [System.Management.Automation.PSCredential]$FarmAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($FarmAccount.UserName)", $FarmAccount.Password)
    [System.Management.Automation.PSCredential]$SPSetupAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SPSetupAccount.UserName)", $SPSetupAccount.Password) 

	Import-DscResource -ModuleName xActiveDirectory, SharePointDsc

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
	
        xADUser CreateFarmAccount
        {
            DomainName =$domainName
            UserName = $FarmAccount.UserName
            DisplayName = "SharePoint Farm Account"
            PasswordNeverExpires = $true            
            Ensure = 'Present'
            Password = $FarmAccountCreds
            DomainAdministratorCredential = $SPSetupAccountCreds
			DependsOn                 = "[WindowsFeature]ADPowerShell"
        }
		
	    SPFarm CreateSPFarm
		{
			Ensure                    = "Present"
			DatabaseServer            = $SqlAlwaysOnEndpointName
			FarmConfigDatabaseName    = "SP_Config_2016"
			Passphrase                = $Passphrase
			FarmAccount               = $FarmAccountCreds
			PsDscRunAsCredential      = $SPSetupAccountCreds
			AdminContentDatabaseName  = "SP_AdminContent"
			CentralAdministrationPort = "2016"
			RunCentralAdmin           = $false
			ServerRole 				  = $ServerRole
			DependsOn                 = "[xADUser]CreateFarmAccount"
		}
	}
}