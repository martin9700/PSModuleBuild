[![Build status](https://ci.appveyor.com/api/projects/status/7w0yl0tn1ut71cek?svg=true)](https://ci.appveyor.com/project/MartinPugh/psmodulebuild) [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PSModuleBuild.svg?style=plastic)](https://www.powershellgallery.com/packages/PSModuleBuild)


# DESCRIPTION
Creating a PowerShell module can be hard, and maintaining it can be even harder.  PSModuleBuild has been designed to make both tasks easier.  In short, you put all of your advanced functions into individual .ps1 files and then invoke PSModuleBuild and let it collect all the functions into a PowerShell module file (.psm1) and create the PowerShell module manifest file (.psd1).


Installation
============
Use the PowerShell Gallery to install PSModuleBuild:
	
	Install-Module PSModuleBuild
	Import-Module PSModuleBuild
	
	
Continuous Integration/Continuous Deployment Support
====================================================
I tried to make PSModuleBuild friendly to CI/CD, specifically some of the community accepted standards for CI like Pester, Psake, etc. by putting in a filter that excludes files with certain keywords in them:
	
	exclude
	tests
	psake\.ps1
	^build\.ps1$
	\.psdeploy\.
	
	
Include.txt
===========
If you have any scripts or cmdlets that need to be run at Import-Module time, you can put them in an Include.txt file and PSModuleBuild will read this file first and put it in the module file first.  This is not strictly needed as PSModuleBuild will read in all .ps1 files and put them in but if you'd like to make sure these commands are run at the beginning of the file you can.


Public/Private Functions
========================
PSModuleBuild will support public and private functions as well.  In your project folder create a Public folder and a Private folder and place your function files appropriately.  


Classes
=======
PSModuleBuild will now support classes.  Create a folder called Classes and put your code in there.

Note: you may run into a situation where one class is required by another class, if this happens you will need to make sure the names of the classes are sortable so that any pre-requisite classes load first.  Example:

    a.firstclass.ps1
    b.secondclass.ps1
    
	

# EXAMPLES

Simple
------
Create a folder, put your function files in it.
	
	Invoke-PSModuleBuild -Path c:\YourModule
	
This will read all of the function files in c:\YourModule and create a module named after the folder (YourModule).
	
Intermediate
------------
Same as simple, but you want to put more information in:

```powershell	
$BuildSplat = @{
	Path         = "c:\YourModule"   
	TargetPath   = "c:\NewModule"
	ModuleName   = "NewModule"
	Author       = "@thesurlyadm1n"
	Description  = "This is that new module I've been working on"
	ProjectURI   = "https://github.com/martin9700/PSModuleBuild"
	ReleaseNotes = "Initial commit"
	Passthru     = $true   #I love feedback
}
Invoke-PSModuleBuild @BuildSplat
```
	
This will create a new module, in a different location and fill the module manifest with the information.  Invoke-PSModuleBuild	supports all of the parameters from New-ModuleManifest.
	
	
Advanced - Additional supporting files
--------------------------------------
If you have about files, or additional XML descriptor files, PSModuleBuild will support that using the Include parameter. All files and folders that you specify with include will be added to the TargetPath.  The name of 
the file/folder is relative to the TargetPath, so Includes below would be in "c:\ProjectFolder\Source" and all 
files and folders *under* Includes would be added to the module.  Path for "Includes" would be 
c:\ProjectFolder\Source\Includes".

```powershell	
$BuildSplat = @{
	Path         = "c:\ProjectFolder\Source"   
	TargetPath   = "c:\ProjectFolder\NewModule"
	ModuleName   = "NewModule"
	Author       = "@thesurlyadm1n"
	Description  = "This is that new module I've been working on"
	ProjectURI   = "https://github.com/martin9700/PSModuleBuild"
	ReleaseNotes = "Initial commit"
	Passthru     = $true
	Includes     = "Includes"
}
Invoke-PSModuleBuild @BuildSplat
```


The folder structure for Includes could be:
```
..\Includes
  \Includes\en-US
  \Includes\en-US\about_NewModule
  \Includes\Templates
  \Includes\Templates\file1.xml
  \Includes\Templates\file2.xml
```

Both the en-US and Templates folders (and their contents) will be included in the module.

	
	
Advanced - Include source files in the module
---------------------------------------------
If you want to include the source function files in your module then specify those files with the Include 
parameter.

```powershell	
$BuildSplat = @{
	Path         = "c:\ProjectFolder\NewModule"   
	TargetPath   = "c:\ProjectFolder\NewModule"
	ModuleName   = "NewModule"
	Author       = "@thesurlyadm1n"
	Description  = "This is that new module I've been working on"
	ProjectURI   = "https://github.com/martin9700/PSModuleBuild"
	ReleaseNotes = "Initial commit"
	Passthru     = $true
	Include      = @("Includes","Private","Public")
}
Invoke-PSModuleBuild @BuildSplat
```
	
	
Advanced - Mulitple Target Paths
--------------------------------
Need to deploy the module to multiple paths?  Maybe you have a primary production location but also a process running in a DMZ?

```powershell	
$BuildSplat = @{
	Path         = "c:\ProjectFolder\NewModule\Source"   
	TargetPath   = "c:\ProjectFolder\NewModule","\\dmzserver\share\Modules\NewModule" 
	ModuleName   = "NewModule"
	Author       = "@thesurlyadm1n"
	Description  = "This is that new module I've been working on"
	ProjectURI   = "https://github.com/martin9700/PSModuleBuild"
	ReleaseNotes = (git log -1 --pretty=%s) | Out-String   #Pull release notes from your git commits
	Passthru     = $true
}
Invoke-PSModuleBuild @BuildSplat
```


# SEE ALSO

- [Continuous Integration](https://en.wikipedia.org/wiki/Continuous_integration)
- [Continuous Deployment](https://en.wikipedia.org/wiki/Continuous_deployment)
- [PSDeploy](https://github.com/RamblingCookieMonster/PSDeploy)
- [Psake](https://github.com/psake/psake)
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer)
	
