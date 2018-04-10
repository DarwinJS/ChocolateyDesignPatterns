$ErrorActionPreference = 'Continue';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

reg import "$toolsDir\Uninstall-ProcmonAppPackagingFilters.reg"