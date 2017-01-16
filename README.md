[![Build status](https://ci.appveyor.com/api/projects/status/7w0yl0tn1ut71cek?svg=true)](https://ci.appveyor.com/project/MartinPugh/psmodulebuild)

#TOPIC
    Building PowerShell Modules with PSModuleBuild

#SHORT DESCRIPTION
	Creating a PowerShell module can be hard, and maintaining it can be even harder.  PSModuleBuild has been designed to make
	both tasks easier.  In short, you put all of your advanced functions into individual .ps1 files and then invoke PSModuleBuild
	and let it collect all the functions into a PowerShell module file (.psm1) and create the PowerShell module manifest
	file (.psd1).
	
#DETAILED DESCRIPTION
	
	Installation
	============
	Use the PowerShell Gallery to install PSModuleBuild:
	
	Install-Module PSModuleBuild
	Import-Module PSModuleBuild
	
	
	Continuous Integration/Continuous Deployment Support
	====================================================
	I tried to make PSModuleBuild friendly to CI/CD, specifically some of the community accepted standards for CI like
	Pester, Psake, etc. by putting in a filter that excludes files with certain keywords in them:
	
	exclude
	tests
	psake\.ps1
	^build\.ps1$
	\.psdeploy\.
	
	
	Include.txt
	===========
	If you have any scripts or cmdlets that need to be run at Import-Module time, you can put them in an Include.txt
	file and PSModuleBuild will read this file first and put it in the module file first.  This is not strictly needed
	as PSModuleBuild will read in all .ps1 files and put them in but if you'd like to make sure these commands are run at
	the beginning of the file you can.
	

#EXAMPLES
	Simple
	------
	Create a folder, put your function files in it.
	
	Invoke-PSModuleBuild -Path c:\YourModule
	
	This will read all of the function files in c:\YourModule and create a module named after the folder (YourModule).
	
	
	Intermediate
	------------
	Same as simple, but you want to put more information in:
	
	$BuildSplat = @{
	   Path = "c:\YourModule"   
	   TargetPath = "c:\NewModule"
	   ModuleName = "NewModule"
	   Author = "@thesurlyadm1n"
	   Description = "This is that new module I've been working on"
	   ProjectURI = "https://github.com/martin9700/PSModuleBuild"
	   ReleaseNotes = "Initial commit"
	   Passthru = $true   #I love feedback
	}
	Invoke-PSModuleBuild @BuildSplat
	
	This will create a new module, in a different location and fill the module manifest with the information.  Invoke-PSModuleBuild
	supports all of the parameters from New-ModuleManifest.
	
	
	Advanced - Additional supporting files
	--------------------------------------
	If you have about files, or additional XML descriptor files, PSModuleBuild will support that.  First create a project folder,
	then create a source folder and place all of your function files in there.  Now create another folder with the name of your
	module (we'll use NewModule in this example) and place all of your files in them in the proper folder structure.
	
	$BuildSplat = @{
	   Path = "c:\ProjectFolder\Source"   
	   TargetPath = "c:\ProjectFolder\NewModule"
	   ModuleName = "NewModule"
	   Author = "@thesurlyadm1n"
	   Description = "This is that new module I've been working on"
	   ProjectURI = "https://github.com/martin9700/PSModuleBuild"
	   ReleaseNotes = "Initial commit"
	   Passthru = $true
	}
	Invoke-PSModuleBuild @BuildSplat
	
	
	Advanced - Include source files in the module
	---------------------------------------------
	If you want to include the source function files in your module create a project folder, then create a folder with
	the name of your project and place all your function files (and other supporting files) in it.
	
	$BuildSplat = @{
	   Path = "c:\ProjectFolder\NewModule"   
	   TargetPath = "c:\ProjectFolder\NewModule"    #this is optional now, Invoke-PSModuleBuild goes here by default
	   ModuleName = "NewModule"
	   Author = "@thesurlyadm1n"
	   Description = "This is that new module I've been working on"
	   ProjectURI = "https://github.com/martin9700/PSModuleBuild"
	   ReleaseNotes = "Initial commit"
	   Passthru = $true
	}
	Invoke-PSModuleBuild @BuildSplat


#SEE ALSO
    Continuous Integration
	Continuous Deployment
	PSDeploy
	Psake
	PSScriptAnalyzer
	
