[![Build status](https://ci.appveyor.com/api/projects/status/34niek0gckruqqlq/branch/master?svg=true)](https://ci.appveyor.com/project/MartinPugh/publish-psmodule/branch/master)

# Publish-PSModule
Simple script for creating a PowerShell module from existing function files

# Description
Put a collection of your favorite functions into their own PS1 files create a PowerShell module.  The module will be named after the folder name they're placed under. Key folders can be used to specify different file types. Unless the path name contains one of the below key names, all functions will be exported by the module and available to the user.

*Private* - if Private is in the path name, all functions found in this path will be not be exported and will not
			be available to the user. However, they will be available as internal functions to the module.
			
*Exclude* - any files found with Exclude in the path name will not be included in the module at all.

*Tests*   - any files found with Tests in the path name will not be included in the module at all (put your Pester
			tests here).

Manifest file for the module will also be created with the correct PowerShell version requirement (assuming you specified this with the "#requires -Version" code in your functions).

Manifest file can also be edited to suit your requirements.
