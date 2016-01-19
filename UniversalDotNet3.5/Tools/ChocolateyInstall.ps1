If(-not (test-path "hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5")) {

  If ([bool](dism /online /get-featureinfo /featurename:NetFx3 | Select-String "Payload Removed"))
  { # set the appropriate policy keys to allow "Removed" features to be pulled from Microsoft
    Write-Output "Dotnet feature is marked removed, making some registry adjustments to ensure it will be successfully pulled from Microsoft."
    $RegKey = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Servicing"

    If (!(Test-Path $RegKey))
    {
      New-Item $RegKey -Force | out-null
      $SaveLocalKey = 'DidNotExist'
    }
    else
    {
      If ([bool]((get-itemproperty $RegKey -ErrorAction SilentlyContinue).LocalSourcePath))
      {
        $SaveLocalSourcePath = (get-itemproperty $RegKey -ErrorAction SilentlyContinue).LocalSourcePath
      }
      else
      {
        $SaveLocalSourcePath = "DidNotExist"
      }

      If ([bool]((get-itemproperty $RegKey -ErrorAction SilentlyContinue).RepairContentServerSource))
      {
        $SaveRepairContentServerSource = (get-itemproperty $RegKey -ErrorAction SilentlyContinue).RepairContentServerSource
      }
      else
      {
        $SaveRepairContentServerSource = "DidNotExist"
      }
    }
    New-ItemProperty -Path $RegKey -Name 'LocalSourcePath' -Type Multistring -Value '' -Force | out-null
    New-ItemProperty -Path $RegKey -Name 'RepairContentServerSource' -Type DWord -Value 2 -Force | out-null
  }


  $statements = "/Online /NoRestart /Enable-Feature /FeatureName:NetFx3"

  If ([version]((gwmi win32_operatingsystem).version) -ge [version]"6.2.9200")
  { #Only add /All for OSes that support it.
    $statements = $statements + " /All"
  }

  write-output "Running: dism.exe $statements"

  Start-ChocolateyProcessAsAdmin -exeToRun 'dism.exe' -statements "$statements" -minimized -nosleep -validExitCodes @(0)

  #Set registry keys back to defaults
  If ($SaveLocalKey -eq 'DidNotExist')
  {
    Remove-Item $RegKey -Recurse -Force
  }
  else
  {
    If ($SaveLocalSourcePath -eq 'DidNotExist')
    {
      Remove-ItemProperty -Path $RegKey -Name 'LocalSourcePath' -Force
    }
    else
    {
      New-ItemProperty -Path $RegKey -Name 'LocalSourcePath' -Type Multistring -Value $SaveLocalSourcePath -Force
    }
    If ($SaveRepairContentServerSource -eq 'DidNotExist')
    {
      Remove-ItemProperty -Path $RegKey -Name 'RepairContentServerSource' -Force
    }
    else
    {
      New-ItemProperty -Path $RegKey -Name 'RepairContentServerSource' -Type Multistring -Value $SaveLocalSourcePath -Force
    }
  }
}
else {
     Write-Host "Microsoft .Net 3.5 Framework is already installed on your machine."
 }
