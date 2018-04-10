$ErrorActionPreference = 'Continue';
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

reg import "$toolsDir\Install-ProcmonAppPackagingFilters.reg"