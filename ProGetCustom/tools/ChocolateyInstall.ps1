$packageName = 'progetcustom'
$installerType = 'EXE'
$downloadUrl  = 'http://inedo.com/proget/download/sql/5.0.10'
$silentArgs = '/S'
#Leave port 80 to have both configured, have only 443 to prevent 80 from being configured
$Port = 82
#$Port = 443
$LogFile = "$env:temp\wwproget_install.log"
$validExitCodes = @(0)

$packageParameters = $env:chocolateyPackageParameters

$arguments = @{
  "Port" = "$Port";
  "Edition" = "LicenseKey";
  "ConnectionString" = "Data Source=localhost\SQLExpress; Initial Catalog=ProGet; Integrated Security=SSPI;";
  "UseIntegratedWebServer" = "False";
  "InstallSQLExpress" = "";
  "ConfigureIIS" = "";
  "S" = "";
  "LogFile" = "$LogFile";
};

If($packageParameters) {
    $MATCH_PATTERN = "/([a-zA-Z]+):([`"'])?([a-zA-Z0-9- _]+)([`"'])?"
    $PARAMATER_NAME_INDEX = 1
    $VALUE_INDEX = 3

    if($packageParameters -match $MATCH_PATTERN ) {
        $results = $packageParameters | Select-String $MATCH_PATTERN -AllMatches
        $results.matches | % {
            $arguments.Set_Item(
                $_.Groups[$PARAMATER_NAME_INDEX].Value.Trim(),
                $_.Groups[$VALUE_INDEX].Value.Trim())
        }
    }
}

$arguments.Keys | % {
    $silentArgs += ' "/' + $_
    If ($arguments[$_]) { $silentArgs += '=' + $arguments[$_]}
    $silentArgs += '"'
}

Write-Output "Adding Web Server and Other Needed Features"

$WinFeatures = @('Web-WebServer','Web-ASP-Net45','Web-Basic-Auth','Web-Mgmt-Console')
Foreach ($WindowsFeature in $WinFeatures)
{
  Add-WindowsFeature $WindowsFeature
}

Write-Output "Removing Default Web Site"
Remove-Website -name 'Default Web Site'

#netsh advfirewall firewall add rule name="ProGet Port 80" dir=in action=allow protocol=TCP localport=80 #Plain port 80 for proget built in
#netsh advfirewall firewall set rule group="World Wide Web Services (HTTP)" new enable=yes #WWW MS rules when IIS installed.  Should be done by Add-WindowsFeature
#netsh advfirewall firewall set rule group="Secure World Wide Web Services (HTTPS)" new enable=yes #WWW MS rules when IIS installed.  Should be done by Add-WindowsFeature

Write-Output "Starting Pro Get installer, install log is located here: $LogFile"

Install-ChocolateyPackage "$packageName" "$installerType" "$silentArgs" "$downloadUrl" -validExitCodes $validExitCodes

get-webbinding -port 443 -name proget -ipaddress '0.0.0.0' | remove-webbinding

New-WebBinding -Name "Proget" -IP "*" -Port 443 -Protocol https

#New-SelfSignedCertificate -DnsName "$env:computerName.$((gwmi win32_ComputerSystem).domain)" -CertStoreLocation cert:\LocalMachine\My
New-SelfSignedCertificate -DnsName "$env:computerName" -CertStoreLocation cert:\LocalMachine\My

Get-ChildItem cert:\LocalMachine\My | where { $_.Subject -match "CN\=$env:Computername\.$((gwmi win32_ComputerSystem).domain)" } | select -First 1 | New-Item IIS:\SslBindings\0.0.0.0!443

If ($Port -eq 443) {$prefix = 'https'} else {$prefix = 'http'}
Write-Output "To open the proget server locally, disable ESC and then visit: $prefix`://localhost:$port"
Write-Output "To open remotely, use $prefix`://$env:computername`:$port"
