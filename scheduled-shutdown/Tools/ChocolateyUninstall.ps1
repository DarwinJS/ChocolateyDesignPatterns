
$packageid = "Scheduled-Shutdown"

If (Test-Path "$env:windir\System32\Tasks\$packageid")
{
  schtasks /delete /tn "$packageid" /F
}
