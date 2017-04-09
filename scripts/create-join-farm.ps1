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
		
		[Parameter(Mandatory)]
        [String]$CreateFarm,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
	)
	
	Import-DscResource -ModuleName xActiveDirectory, SharePointDsc
    [System.Management.Automation.PSCredential]$PassphraseCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Passphrase.UserName)", $Passphrase.Password)
    [System.Management.Automation.PSCredential]$FarmAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($FarmAccount.UserName)", $FarmAccount.Password)
    [System.Management.Automation.PSCredential]$SPSetupAccountCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($SPSetupAccount.UserName)", $SPSetupAccount.Password)

    $RebootVirtualMachine = $false
	$PSDscAllowDomainUser = $true
    if ($DomainName)
    {
        $RebootVirtualMachine = $true
    }
	node "localhost"
    {
	
	    xADUser CreateFarmAccount
        {
            DomainAdministratorCredential = $SPSetupAccountCreds
            DomainName = $DomainName
            UserName = $FarmAccount.UserName
            Password = $FarmAccount.Password
            Ensure = "Present"
        }
		
		if ($CreateFarm -eq  "True")
		{
	    SPCreateFarm CreateSPFarm
			{
				DatabaseServer            = $SqlAlwaysOnEndpointName
				FarmConfigDatabaseName    = "SP_Config_2016"
				Passphrase                = $PassphraseCreds
				FarmAccount               = $FarmAccountCreds
				PsDscRunAsCredential      = $SPSetupAccountCreds
				AdminContentDatabaseName  = "SP_AdminContent"
				CentralAdministrationPort = "2016"
				ServerRole 				  = $ServerRole
				DependsOn                 = "[xADUser]CreateFarmAccount"
			}
		}
		else
		{
	    SPJoinFarm JoinSPFarm
			{
				DatabaseServer            = $SqlAlwaysOnEndpointName
				FarmConfigDatabaseName    = "SP_Config_2016"
				Passphrase                = $PassphraseCreds
				PsDscRunAsCredential      = $SPSetupAccountCreds
				ServerRole 				  = $ServerRole
				DependsOn                 = "[xADUser]CreateFarmAccount"
			}
		}
	}
}