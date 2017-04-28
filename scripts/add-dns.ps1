﻿Import-Module DNSServer

Add-DnsServerResourceRecordA -Name "Portal" -ZoneName "contoso.com" -AllowUpdateAny -IPv4Address "10.0.1.100" -TimeToLive 01:00:00 -ComputerName "AD1.contoso.com"
Add-DnsServerResourceRecordA -Name "OneDrive" -ZoneName "contoso.com" -AllowUpdateAny -IPv4Address "10.0.1.100" -TimeToLive 01:00:00 -ComputerName "AD1.contoso.com"
