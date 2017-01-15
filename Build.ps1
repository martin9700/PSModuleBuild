# Grab nuget bits, install modules, set build variables, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

#Now PSGallery
Import-Module PowerShellGet -ErrorAction Stop
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module psake,Pester,PSScriptAnalyzer,PSModuleBuild

#Start the process
Invoke-psake .\Psake.ps1