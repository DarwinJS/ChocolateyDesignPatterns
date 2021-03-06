
## Symptoms This Code Resolves for Automation

### One of the following commands produces the below errors:
DISM /Online /NoRestart /Enable-Feature /FeatureName:NetFx3 /All
DISM /Online /NoRestart /Enable-Feature /FeatureName:MicrosoftWindowsPowerShell /All
DISM /Online /NoRestart /Enable-Feature /FeatureName:MicrosoftWindowsPowerShellRoot

Error: 0x800f0906

The source files could not be downloaded.
Use the "source" option to specify the location of the files that are required to restore the feature. For more informat
ion on specifying a source location, see http://go.microsoft.com/fwlink/?LinkId=243077.

### The DISM log file contains errors like these (found at C:\Windows\Logs\DISM\dism.log)

The cited log shows errors similar to these:
Error                 DISM   DISM Package Manager: PID=1124 TID=2068 Failed finalizing changes. - CDISMPackageManager::Internal_Finalize(hr:0x800f0906)
Error                 DISM   DISM Package Manager: PID=1124 TID=2068 The source files could not be found and download failed. Their location can be specified using the /source option to restore the feature. - GetCbsErrorMsg
Error                 DISM   DISM Package Manager: PID=1124 TID=2068 Failed processing package changes with session options - CDISMPackageManager::ProcessChangesWithOptions(hr:0x800f0906)
Error                 DISM   DISM Package Manager: PID=1124 TID=2068 Failed ProcessChanges. - CPackageManagerCLIHandler::Private_ProcessFeatureChange(hr:0x800f0906)
Error                 DISM   DISM Package Manager: PID=1124 TID=2068 Failed while processing command enable-feature. - CPackageManagerCLIHandler::ExecuteCmdLine(hr:0x800f0906)

### One of the following commands produces the below errors:
"Add-WindowsFeature Net-Framework-Core"
"Install-WindowsFeature Net-Framework-Core"
"Add-WindowsFeature PowerShell-V2"
"Install-WindowsFeature PowerShell-V2"

Installation of one or more roles, role services, or features failed.
The source files could not be downloaded.
Use the "source" option to specify the location of the files that are required to restore the feature. For more
information on specifying a source location, see http://go.microsoft.com/fwlink/?LinkId=243077. Error: 0x800f0906
At line:1 char:1
+ add-windowsfeature net-framework-core
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (@{Vhd=; Credent...Name=localhost}:PSObject) [Install-WindowsFeature],
    Exception
    + FullyQualifiedErrorId : DISMAPI_Error__Cbs_Download_Failure,Microsoft.Windows.ServerManager.Commands.AddWindowsF
   eatureCommand

Success Restart Needed Exit Code      Feature Result
------- -------------- ---------      --------------
False   No             Failed         {}

And C:\Windows\Logs\CBS\CBS.log will contain many lines like this - with the last line repeating many times:
Info                  CSI Transaction @0xb914dd25c0 initialized for deployment engine ...
Info                  CBS    Exec: Staging Package: Microsoft-Windows-NetFx3-Server ...
Info                  CBS    Exec: Not able to pre-stage package: Microsoft-Windows-UpdateServices-CoreServices-Package ...

## The Problem
The features for .NET 3.5, 3.0 and 2.0 as well as PowerShell Version 2 are "removed" in a standard build of Windows Server 2012 R2 and later.
In theory, these features should be acquired from Microsoft through Windows Update by default with no action on your part.
In practice this happens *sometimes* but not *others*.  I have witnessed it working and not working on two virtually identical builds of Server 2012 R2 Standard Trial.  I compared all the Windows Updates policy registry keys and they were identical.  I compared output of Win32_OperatingSystem and they were identical (including sku).  The only substantial difference was that the one that worked had had *some* windows updates applied and on the other there were none.
From this I deduce that one had Windows Updated disabled during first boot and never had the opportunity to contact Windows Update even once, while the other had contacted it at least once, but was now disabled.

I have also observed that on a system that fails, immediate re-issuance of the command may then work.  This work around is not suitable for all situations because: [a] I have not seen it work reliably, [b] desired state systems (Chef, Puppet, PowerShell DSC) may be hard to code to "poke this and have it fail" now do do it again, especially if the feature install is part of a dependency resolution.

However, this observation also supports the hypothesis that the state of the machine is somehow different after an initial attempt to touch Windows Update.

So the claimed default behavior seems to me to only be true if Windows Update has been touched successfully at least one time in the past.  I'm not sure if it's *any* type of touch or specific types - but it does consistently fail on that initial touch no matter which windows feature commands are used to try to pull a disabled feature.

## The Solution: Make *Claimed* Default Behavior *Explicit*
Most solutions you find on the web will indicate that you need to reference a copy of the folder ...\sources\sxs from the install media with the source parameter.   Although this works, if you are supporting a complex, multi-cloud environment, **using automation** it is much more than a small pain to provide this folder and all the required logic and config to relatively reference the folder in every environment.  It would be so much nicer if it would just work - and it can.
The solution is to change the windows update policy keys to explicitly let it know it's OK to contact Windows Updates to pull down "Removed" features before attempting the first touch.

The screenshot of the dialog "Specify settings for optional component installation and component repair" in this article [http://blogs.technet.com/b/askpfeplat/archive/2013/02/24/how-to-reduce-the-size-of-the-winsxs-directory-and-free-up-disk-space-on-windows-server-2012-using-features-on-demand.aspx] shows the policy setting change that must be made.  The policy must be enabled and the last box check (check box text is "Contact Windows Update directly to download repair content instead of Windows Server Update Services (WSUS)").

I have boiled that down to the specific settings of two registry keys that remedy the situation in my scenario (seeming a machine that during build had Windows Update disabled and has never contacted Windows Update before the attempt to install a removed windows optional feature).

I have coded the change of these two keys to return the keys to the prior state so that if the keys are being managed by something else (static build properties, DSC, group policy), we put them back to how we found them.  If you are confident there is no other management or use of the keys you could just slam them in and leave them or remove them afterward without worrying about prior values.  This code also is minimalist in that they keys are not touched if the feature is not marked "Removed".

This code is part of a Chocolatey Nuget package, but should work just fine as a stand-alone script as well.  It is here: [https://github.com/DarwinJS/ChocolateyDesignPatterns/blob/master/UniversalDotNet3.5/Tools/ChocolateyInstall.ps1]

Here is the simple .REG files that remedies this:
Windows Registry Editor Version 5.00
```
[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing]
"LocalSourcePath"=hex(7):00,00
"RepairContentServerSource"=dword:00000002

[HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\Servicing]
"LocalSourcePath"=hex(7):00,00
"RepairContentServerSource"=dword:00000002
```
**CAUTION**: Some sources I consulted indicated that if DISM or Add-WindowsFeature is run in a 32-bit **process**, you will need to tweak the windows update policy keys under Wow3264Node.  I did not have time nor need to test this.  **DO NOT ASSUME YOU WILL HAVE 64-bit PROCESS EXECUTION IN ANY GIVEN CIRCUMSTANCE**.  For instance, SCCM 2012 R2 *Application Objects* run as 64-bit *processes*, but SCCM 2012 R2 *Package Objects* run as *32-bit processes*.  Any management system agent (e.g. Chef, Pupppet) may run in either bitness and many vendors choose to retain a 32-bit *process* implementation because it allows the same agent code to service both 32 and 64-bit Windows clients.  Also, some agents take pains to run your code in a 64-bit *process* even though they themselves are a 32-bit executable.  For instance Chef 12.x client running as a service is a 32-bit ruby.exe *process*, but when running on the 64-bit OS it executes any requested PowerShell as a 64-bit *process*.  The same is true of Chocolatey execution - it's 32-bit, but runs PowerShell as 64-bit.

## PostScript Note
The reason the code in this solution uses "dism.exe" and only adds the "/All" command to specific versions of Windows, is to enable it work across the maximum scope of Windows Desktop and Server editions.
Not using DISM, get's you into a matrix of permutations of required commands that are different for various OS editions and versions - this complexity is aptly outlined here: http://peter.hahndorf.eu/blog/WindowsFeatureViaCmd

The code in this solution should work from Windows 7/Server 2008 R2 through Windows 10 / Server 2016 and Nano and quite possibly beyond.

The use case where this is important for me is when I want the deployment of IIS on developer Desktop operating systems to match our server environment as closely as possible.
