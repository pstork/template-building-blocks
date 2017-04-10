configuration CreateJoinFarm
{

        [String]$domainName = "Contoso"
		
        [String]$SqlAlwaysOnEndpointName = ""
		
		$secpasswd = ConvertTo-SecureString “AweS0me@PW” -AsPlainText -Force

        [System.Management.Automation.PSCredential]$PassphraseCreds = New-Object System.Management.Automation.PSCredential ("contoso\testuser", $secpasswd)

        [System.Management.Automation.PSCredential]$FarmAccountCreds = New-Object System.Management.Automation.PSCredential ("contoso\sp_install", $secpasswd)

        [System.Management.Automation.PSCredential]$SPSetupAccountCreds  = New-Object System.Management.Automation.PSCredential ("contoso\testuser", $secpasswd)
		
        [String]$ServerRole = "Application"
		
        [String]$CreateFarm = "True"

        [Int]$RetryCount=20
        [Int]$RetryIntervalSec=30
	
	Import-DscResource -ModuleName xActiveDirectory, SharePointDsc

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
            UserName = "Testuser"
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