
$packageid = "Scheduled-Shutdown"
$ShutdownTime = '23:50' #Hour in 24hr / min format
$Frequency = 'Daily' #Daily or Weekly
$Weekday = 'FRI'
$Modifier  = $null

$arguments = @{};
ConvertFrom-ChocoPackageParamsToVariables -ParamString $env:chocolateyPackageParameters

<#
$packageParameters = $env:chocolateyPackageParameters;

# Now parse the packageParameters using good old regular expression
if ($packageParameters) {
    $match_pattern = "\/(?<option>([a-zA-Z]+)):(?<value>([`"'])?([a-zA-Z0-9- _\\:\.]+)([`"'])?)|\/(?<option>([a-zA-Z]+))"
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
    if ($arguments.ContainsKey("ShutdownTime")) {
        Write-Output "ShutdownTime argument used, changing from default $Shutdown time to $($arguments.Get_Item("ShutdownTime"))"
        $ShutdownTime = $arguments.Get_Item("ShutdownTime")
    }
    if ($arguments.ContainsKey("Frequency")) {
        Write-Output "Frequency argument used, changing from default $Frequency time to $($arguments.Get_Item("Frequency"))"
        $Frequency = $arguments["Frequency"]
    }
    if ($arguments.ContainsKey("Weekday")) {
      If ($Frequency -ieq 'Daily')
        {
          Write-Ouput "Ignoring Weekday argument set to $Weekday because Frequency is set to $Frequency (you must set Frequency to Weekly for Weekday to be relevant)"
        }
        else
        {
          Write-Output "Weekday argument used, changing from default $Weekday time to $($arguments.Get_Item("Weekday"))"
          $Weekday = $arguments["Weekday"]
        }
    }
} else {
    Write-Debug "No Package Parameters Passed in, using defaults.";
}
#>

If ($Frequency -ieq "Weekly")
{
  $modifier = " /MO 1 /D $Weekday "
}


If (Test-Path "$env:windir\System32\Tasks\$packageid")
{
  schtasks /delete /tn "$packageid" /F
}

$argumentstring = "/create /sc `"$Frequency`" /tn `"$packageid`" /ru `"NT AUTHORITY\SYSTEM`" /tr `"c:\windows\system32\shutdown.exe /s /t 120 /c $packageid /f`" /st `"$ShutdownTime`" $modifier"

Write-output "Scheduling with command: "
Write-Output "$argumentstring"

Start-process "schtasks.exe" -ArgumentList "$argumentstring" -nonewwindow -wait

$StatusMessage = "Shutdown is scheduled for $ShutdownTime on a $Frequency Basis"

If ($Frequency -ieq 'Weekly')
{
  $StatusMessage += " every $Weekday."
}

Write-warning "**********************************************************************"
Write-warning "$StatusMessage"
Write-warning "**********************************************************************"

Write-Output "`r`nRerun this package ($packageid) with parameter `"-Force`", to remove shutdown schedule, uninstall this package."
