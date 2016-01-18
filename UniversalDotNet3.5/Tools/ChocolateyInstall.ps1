if(-not (test-path "hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5")) {

  If (Windows 2012 or later)
  {
    If (Get-WIndowsFeature blah -eq "Removed")
    { # set the appropriate policy keys to allow "Removed" features to be pulled from Microsoft
      Write-Output "Dotnet feature is marked removed, making some registry adjustments to ensure it will be pulled from Microsoft."
      $RegKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Servicing"
      $read = "$RegKey\LocalSourcePath"
      $read = "$RegKey\RepairContentServerSource"

      Set LocalsourePath REGSZ_MULTI - blank
      Set RepairContentServerSource Dword 2
    }
  }

  $packageArgs = "/c DISM /Online /NoRestart /Enable-Feature /FeatureName:NetFx3 /All"
  $statements = "cmd.exe $packageArgs"
  Start-ChocolateyProcessAsAdmin "$statements" -minimized -nosleep -validExitCodes @(0)

  #Set registry keys back to defaults

}
else {
     Write-Host "Microsoft .Net 3.5 Framework is already installed on your machine."
 }
