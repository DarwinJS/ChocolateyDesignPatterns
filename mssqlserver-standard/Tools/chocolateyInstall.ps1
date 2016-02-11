
$packageID = 'mssqlserver-standard'
$validExitCodes = @(0,3010)

$adminsGroupName = (New-Object Security.Principal.SecurityIdentifier 'S-1-5-32-544').Translate([Security.Principal.NTAccount]).Value

$SQL_WhatIf = $False
$SQL_QuietSwitch = "Q"
$SQL_InstanceName = 'MSSQLSERVER'
$SQL_Features = 'SQLENGINE,FULLTEXT,CONN,IS,BC,SDK,SSMS,ADV_SSMS'
$SQL_SecurityMode = $null
$SQL_SAPwd = 'BestPassword2Have' #Password must meet operating system configured complexity requirements or install will fail.
$SQL_BROWSERSVCSTARTUPTYPE = 'Automatic'
$SQL_SQLSVCSTARTUPTYPE = 'Automatic'

$arguments = @{};
$packageParameters = $env:chocolateyPackageParameters;

# Now parse the packageParameters using good old regular expression
if ($packageParameters) {
    $match_pattern = "\/(?<option>([a-zA-Z_]+)):(?<value>([`"'])?([a-zA-Z0-9- _\@\\:\.]+)([`"'])?)|\/(?<option>([a-zA-Z]+))"
    #"
    $option_name = 'option'
    $value_name = 'value'

    if ($packageParameters -match $match_pattern ){
        $results = $packageParameters | Select-String $match_pattern -AllMatches
        $results.matches | % {
          $arguments.Add(
              $_.Groups[$option_name].Value.Trim(),
              $_.Groups[$value_name].Value.Trim())
      }
    }
    else
    {
      throw "Package Parameters were found but were invalid (REGEX Failure)"
    }

    if ($arguments.ContainsKey("SQL_WhatIf"))
    {
        $SQL_WhatIf = $True
    }
    if ($arguments.ContainsKey("SQL_SourceLocation"))
    {
        $SQL_SourceLocation = $arguments.Get_Item("SQL_SourceLocation")
    }
    if ($arguments.ContainsKey("SQL_SourceUser"))
    {
        if (!($arguments.ContainsKey("SQL_SourcePass")))
        {
          Throw "You have provided SQL_SourceUser without providing SQL_SourcePass - if one is specified, both must be specified."
        }
        Else
        {
          $SQL_SourceUser = $arguments.Get_Item("SQL_SourceUser")
        }
    }
    if ($arguments.ContainsKey("SQL_SourcePass"))
    {
      if (!($arguments.ContainsKey("SQL_SourceUser")))
      {
        Throw "You have provided SQL_SourcePass without providing SQL_SourceUser - if one is specified, both must be specified."
      }
      Else
      {
        $SQL_SourcePass = $arguments.Get_Item("SQL_SourcePass")
      }
    }
    if ($arguments.ContainsKey("SQL_QuietSwitch")) {
        $SQL_QuietSwitch = $arguments.Get_Item("SQL_QuietSwitch")
    }
    if ($arguments.ContainsKey("SQL_SecurityMode")) {
        $SQL_SecurityMode = $arguments.Get_Item("SQL_SecurityMode")
    }
    if ($arguments.ContainsKey("SQL_SAPwd")) {
        $SQL_SAPwd = $arguments.Get_Item("SQL_SAPwd")
    }
    if ($arguments.ContainsKey("SQL_Features")) {
        $SQL_Features = $arguments.Get_Item("SQL_Features")
    }
    if ($arguments.ContainsKey("SQL_InstanceName")) {
        $SQL_InstanceName = $arguments.Get_Item("SQL_InstanceName")
    }
    if ($arguments.ContainsKey("SQL_BROWSERSVCSTARTUPTYPE")) {
        $SQL_BROWSERSVCSTARTUPTYPE = $arguments.Get_Item("SQL_BROWSERSVCSTARTUPTYPE")
    }
    if ($arguments.ContainsKey("SQL_BROWSERSVCSTARTUPTYPE")) {
        $SQL_BROWSERSVCSTARTUPTYPE = $arguments.Get_Item("SQL_BROWSERSVCSTARTUPTYPE")
    }
    if ($arguments.ContainsKey("SQL_SQLSVCSTARTUPTYPE")) {
        $SQL_SQLSVCSTARTUPTYPE = $arguments.Get_Item("SQL_SQLSVCSTARTUPTYPE")
    }

    if ($arguments.ContainsKey("OverrideSQLCMDLineFile"))
    {
        $SQLSetupParameters = Get-content $($arguments.Get_Item("OverrideSQLCMDLineFile"))
        $FullSQLCommandOverride = $True
        Write-Output "A full override of the SQL command has been configured - all other arguments will be ignored and we will use:"
        Write-Output "$SQLSetupParameters"
    }
} else
{
    Write-Debug "No Package Parameters Passed in";
    Throw "Package requires at least SQL_SourceLocation to find SQL setup.exe"
}

If (!$FullSQLCommandOverride)
{
  $SQLSetupParameters = $SQLDisplayParameters = "/ACTION=Install /$($SQL_QuietSwitch) /INDICATEPROGRESS /IACCEPTSQLSERVERLICENSETERMS /FEATURES=$SQL_Features /TCPENABLED=1 /INSTANCENAME=$SQL_InstanceName /BROWSERSVCSTARTUPTYPE=$SQL_BROWSERSVCSTARTUPTYPE /SQLSVCSTARTUPTYPE=$SQL_SQLSVCSTARTUPTYPE /SQLSVCACCOUNT=`"NT AUTHORITY\Network Service`" /SQLSYSADMINACCOUNTS=`"$adminsGroupName`" /AGTSVCACCOUNT=`"NT AUTHORITY\Network Service`""
  If ($SQL_SecurityMode -ieq 'SQL')
  {
    If (!$SQL_SAPwd)
    {
      Throw 'You must specify SQL_SAPwd if SQL_SecurityMode is set to "SQL"'
    }
    Else
    {
      $SQLSetupParameters += " /SECURITYMODE=$SQL_SecurityMode /SAPWD=`"$SQL_SAPwd`""
      $SQLDisplayParameters += " /SECURITYMODE=$SQL_SecurityMode (SQL_SAPwd left out for security)"
    }
  }
}

Write-Output "********************************************************"
Write-Output "$SQLDisplayParameters"
Write-Output "********************************************************"

<#Were given user name and passwords - prepare $RemoteShareConnectionCreds
$RemoteShareConnectionCreds = $null
If ((Test-Path variable:SQL_SourceUser) -AND ($SQL_SourceUser))
{ #Setup Remote Creds Object if we have the info to do so
  $SecurePassword = ConvertTo-SecureString -String $SQL_SourcePass -AsPlainText -Force
  $RemoteShareConnectionCreds = New-Object System.Management.Automation.PSCredential ("$SQL_SourceUser", $SecurePassword)
}
#>

$SqlSetupEXE = Join-Path "$SQL_SourceLocation" 'setup.exe'

If (($SqlSetupEXE).contains(':\'))
{
  $SQLSourceURI = 'DriveLetter'
  #Lets find out if this is a mapped drive letter
  $DL = Split-Path -qualifier "$SqlSetupEXE"
  $logicalDisk = Gwmi Win32_LogicalDisk -filter "DriveType = 4 AND DeviceID = '$DL'"
  If ($logicalDisk)
  {
    $URIToAuthenticate = $logicalDisk.ProviderName
    $pathparts = $URIToAuthenticate.split('\')
    $HostToPing = "$($pathparts[2])"
    $SQLSourceLocType = 'Network'
  }
  Else
  {
    $URIToAuthenticate = $null
    $HostToPing = $null
    $SQLSourceLocType = 'Local'
    If ($RemoteShareConnectionCreds)
    {
      Write-Warning "Your provided credentials when the location $SqlSetupEXE is not on a mapped drive, will not attempt authentication."
      $RemoteShareConnectionCreds = $null
      $SQL_SourceUser = $null
      $SQL_SourcePass = $null
    }
  }
}
ElseIf ($SqlSetupEXE.StartsWith('\\'))
{
  $SQLSourceURI = 'UNC'
  $pathparts = $pathparts = $SqlSetupEXE.split('\')
  $URIToAuthenticate = join-path "\\$($pathparts[2])" "$($pathparts[3])"
  $HostToPing = "$($pathparts[2])"
  $SQLSourceLocType = 'Network'
}
Else
{
  Throw "Source location string does not start with a UNC or Drive Letter reference"
}

#Do some logging that could be very helpful for debugging remote setup source mistakes
Write-Output "`r`nThe path $SqlSetupEXE is a $SQLSourceLocType $SQLSourceURI"
Write-Output "Will need to:"
If ($HostToPing) {Write-Output "  *) Ping $HostToPing"}
If ((Test-Path variable:SQL_SourceUser) -AND ($SQLSourceLocType -ieq 'Network')) {Write-Output "  *) Authenticate to $URIToAuthenticate with provided user id: $SQL_SourceUser"}
Write-Output "  *) Test existence of $SqlSetupEXE"
Write-Output "  *) Add `"$HostToPing`" to trusted zone to allow remote execution of setup.exe"
Write-Output "`r`n"

If ($HostToPing)
{
  If (!(Test-Connection $HostToPing))
  {
    Throw "Could not touch $HostToPing"
  }
  Else
  {
    Write-Output "Successfully pinged $HostToPing..."
  }
}

If ((Test-Path variable:SQL_SourceUser) -AND ($SQLSourceLocType -ieq 'Network'))
{
  $Authenticate_cmd = "net.exe use $URIToAuthenticate $SQL_SourcePass /user:`"$SQL_SourceUser`""

  $Results = Invoke-Expression $Authenticate_cmd
  If ($Results -ilike "*command completed successfully*")
  {
    $AuthenticationSuccess = $True
    Write-Output "Was able to authenticate to `"$URIToAuthenticate`" ..."
  }
  Else
  {
    Throw "Could not authenticate to $URIToAuthenticate  (Be sure you have not specified a user name and password if the current user already has a connection to the remote.)"
  }
}

If (Test-Path $SqlSetupEXE)
{
  $SetupEXEFileInfo = Get-Command "$SqlSetupEXE"
  Write-Output "Was able to find `"$SqlSetupEXE`" which contains the following meta-data:"
  Write-Output "          Product: $($SetupEXEFileInfo.FileVersionInfo.ProductName)"
  Write-Output "  FileDescription: $($SetupEXEFileInfo.FileVersionInfo.FileDescription)"
  Write-Output "      FileVersion: $($SetupEXEFileInfo.FileVersionInfo.FileVersion)"
  Write-Output "   ProductVersion: $($SetupEXEFileInfo.FileVersionInfo.ProductVersion)"

  If (!$SQL_WhatIf)
  {
    Write-Output "Adding $HostToPing to Trusted Sites Zone to allow remote execution of `"$SqlSetupEXE`""
    New-Item -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\$HostToPing" -Force | Out-Null
    New-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\$HostToPing" -Name '*' -Value 1 -PropertyType DWORD -Force | Out-Null
  }
  Else
  {
    Write-Output "When not using SQL_WhatIf: Will Add $HostToPing to Trusted Sites Zone to allow remote execution of `"$SqlSetupEXE`""
  }
}
Else
{
  Throw "Could not find `"$SqlSetupEXE`".  Besure that the location exists and that the user has file permissions and share permissions for network locations."
}

If ($SQL_WhatIf)
{
  Write-Warning "/SQL_Whatif was used, not running the install command.  Use '-Force' to keep running command line tests."
  Exit
}
Else
{
  Start-ChocolateyProcessAsAdmin -exeToRun $SqlSetupEXE -statements $SQLSetupParameters -validExitCodes $validExitCodes
  If ($SQL_SAPwd) {Write-Warning "SA password was set as requested in the command line."}
  Write-Warning "SQL Server Install Always Requires a Restart Before Setup Will Be Complete"
}
