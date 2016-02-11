
$validExitCodes = @(0,3010)
$arguments = @{};
$packageParameters = $env:chocolateyPackageParameters;

# Now parse the packageParameters using good old regular expression
if ($packageParameters)
{
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

    if ($arguments.ContainsKey("ToggleWUIfNecessary"))
    {
        $ToggleWUIfNecessary = $True
    }
}

If(-not (test-path "hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5")) {

  If ([bool](dism /online /get-featureinfo /featurename:NetFx3 | Select-String "Payload Removed"))
  { # set the appropriate policy keys to allow "Removed" features to be pulled from Microsoft
    Write-Output "Dotnet feature is marked removed, making some registry adjustments to ensure it will be successfully pulled from Microsoft."

    IF ((Get-WmiObject -Class Win32_Service -Property StartMode -Filter "Name='wuauserv'").StartMode -ieq 'Disabled')
    {
      $WindowsUpdateFoundInDisabledState = $True
      If ($ToggleWUIfNecessary)
      {
        Write-Output "Windows Updated is disabled and the package parameter ToggleWUIfNecessary is set, temporarily enabling Windows Update..."
        Set-Service wuauserv -StartupType 'Manual'
      }
      Else
      {
        Throw "This system has Windows Updated disabled and the Dot Net 3.5 Feature is Marked 'Removed', Use package switch -Params '`"/ToggleWUIfNecessary:true`"' to allow this package to temporarily enabled Windows update to get the feature from Microsoft."
      }

    }

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

  Start-ChocolateyProcessAsAdmin -exeToRun 'dism.exe' -statements "$statements" -minimized -nosleep -validExitCodes $validExitCodes
  If ($WindowsUpdateFoundInDisabledState)
  {
    Write-Output "Windows Update was found in a disabled stated and enabled for this package run, stopping and disabling it..."
    Stop-Service wuauserv -Force
    Set-Service wuauserv -StartupType 'Disabled'
  }

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
      New-ItemProperty -Path $RegKey -Name 'LocalSourcePath' -Type Multistring -Value $SaveLocalSourcePath -Force | out-null
    }
    If ($SaveRepairContentServerSource -eq 'DidNotExist')
    {
      Remove-ItemProperty -Path $RegKey -Name 'RepairContentServerSource' -Force
    }
    else
    {
      New-ItemProperty -Path $RegKey -Name 'RepairContentServerSource' -Type DWord -Value $SaveRepairContentServerSource -Force | out-null
    }
  }
}
else {
     Write-Host "Microsoft .Net 3.5 Framework is already installed on your machine."
 }
