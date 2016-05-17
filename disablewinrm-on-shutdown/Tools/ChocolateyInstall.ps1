
$packageid = "disablewinrm-on-shutdown"

Write-Output 'Disabling PS Remoting On Next Shutdown'
#Write a file and call it in runonce
$psScriptsFile = "C:\Windows\System32\GroupPolicy\Machine\Scripts\psscripts.ini"
$Key1 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Shutdown\0'
$Key2 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Scripts\Shutdown\0'
$keys = @($key1,$key2)
$scriptpath = "C:\Windows\System32\GroupPolicy\Machine\Scripts\Shutdown\disablepsremoting.ps1"
#$selfdeletescriptpath = "C:\Windows\System32\GroupPolicy\Machine\Scripts\Shutdown\disablepsremotingdelete.ps1"
$scriptfilename = (Split-Path -leaf $scriptpath)
$ScriptFolder = (Split-Path -parent $scriptpath)
#$taskname = "Selfdelete_disablewinrm-on-shutdown"

$selfdeletescript = @"
Start-Sleep -milliseconds 500
Remove-Item "$key1" -Force -Recurse
Remove-Item "$key2" -Force -Recurse
Remove-Item "$scriptpath" -Force
#Remove-Item "$selfdeletescriptpath" -Force
(Get-Content "$psScriptsFile") -replace '0CmdLine=$scriptfilename', '' | Set-Content "$psScriptsFile"
(Get-Content "$psScriptsFile") -replace '0Parameters=', '' | Set-Content "$psScriptsFile"
#If ($Error) {`$Error | fl * -force | out-string | out-file "$env:public\selfdeleteerrors.txt"}
"@

$selfdeletescript =[Scriptblock]::Create($selfdeletescript)

$scripttowrite = @"
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/service/auth '@{Basic="false"}'
winrm delete winrm/config/Listener?Address=*+Transport=HTTP
Disable-PSRemoting
netsh advfirewall firewall delete rule name="Windows Remote Management (HTTP-In)"
#Start-Process "powershell.exe" -Argumentlist "-noprofile -executionpolicy bypass -file $selfdeletescriptpath"
Register-ScheduledJob -Name CleanUpWinRM -RunNow -ScheduledJobOption @{RunElevated=$True;ShowInTaskScheduler=$True;RunWithoutNetwork=$True} -ScriptBlock $selfdeletescript
"@

If (!(Test-Path $ScriptFolder)) {New-Item $ScriptFolder -type Directory -force}
Set-Content -path $scriptpath -value $scripttowrite

#Set-Content -path $selfdeletescriptpath -value $selfdeletescript

#schtasks.exe /create /TN $taskName /SC ONSTART /NP /TR "powershell.exe -noprofile -executionpolicy bypass -file $selfdeletescriptpath"
#Register-ScheduledJob -Name CleanUpWinRM -Trigger (New-JobTrigger -AtStartup -RandomDelay 00:00:00:05) -ScheduledJobOption @{RunElevated=$True;ShowInTaskScheduler=$True;RunWithoutNetwork=$True} -ScriptBlock $selfdeletescript
#Register-ScheduledJob -Name CleanUpWinRM -Trigger (New-JobTrigger -AtStartup -RandomDelay 00:00:00:05) -ScheduledJobOption @{ShowInTaskScheduler=$True;RunWithoutNetwork=$True} -File $selfdeletescriptpath

Foreach ($Key in $keys)
{
New-Item -Path $key -Force | out-null
New-ItemProperty -Path $key -Name GPO-ID -Value LocalGPO -Force | out-null
New-ItemProperty -Path $key -Name SOM-ID -Value Local -Force | out-null
New-ItemProperty -Path $key -Name FileSysPath -Value "C:\Windows\System32\GroupPolicy\Machine" -Force | out-null
New-ItemProperty -Path $key -Name DisplayName -Value "Local Group Policy" -Force | out-null
New-ItemProperty -Path $key -Name GPOName -Value "Local Group Policy" -Force | out-null
New-ItemProperty -Path $key -Name PSScriptOrder -Value 1 -PropertyType "DWord" -Force | out-null

$key = "$key\0"
New-Item -Path $key -Force | out-null
New-ItemProperty -Path $key -Name "Script" -Value $scriptfilename -Force | out-null
New-ItemProperty -Path $key -Name "Parameters" -Value $parameters -Force | out-null
New-ItemProperty -Path $key -Name "IsPowershell" -Value 1 -PropertyType "DWord" -Force | out-null
New-ItemProperty -Path $key -Name "ExecTime" -Value 0 -PropertyType "QWord" -Force | out-null
}

If (!(Test-Path $psScriptsFile)) {New-Item $psScriptsFile -type file -force}
"[Shutdown]" | Out-File $psScriptsFile
"0CmdLine=$scriptfilename" | Out-File $psScriptsFile -Append
"0Parameters=$parameters" | Out-File $psScriptsFile -Append
