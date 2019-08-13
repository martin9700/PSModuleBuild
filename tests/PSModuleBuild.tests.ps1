#Set up
$ScriptPath = $ENV:APPVEYOR_BUILD_FOLDER
Import-Module "$ENV:APPVEYOR_BUILD_FOLDER\PSModuleBuild"
<#Non-appveyor testing
$ScriptPath = "c:\dropbox\github\PSModuleBuild"
. $ScriptPath\Source\Public\Invoke-PSModuleBuild.ps1
. $ScriptPath\Source\Private\CreateUpdateManifest.ps1
#>

#Clean up
Remove-Item $ScriptPath\Test-Module -Recurse -Force -ErrorAction SilentlyContinue

#Testing
Describe "Testing Invoke-PSModuleBuild module builds" {
    Context "Scratch build" {
        New-Item $ScriptPath\Test-Module\Source                -ItemType Directory
        New-Item $ScriptPath\Test-Module\Source\Public         -ItemType Directory
        New-Item $ScriptPath\Test-Module\Source\Private        -ItemType Directory
        New-Item $ScriptPath\Test-Module\Source\Classes        -ItemType Directory
        New-Item $ScriptPath\Test-Module\Source\Tests          -ItemType Directory
        New-Item $ScriptPath\Test-Module\Source\Includes       -ItemType Directory
        New-Item $ScriptPath\Test-Module\Source\Includes\en-US -ItemType Directory

        "Function Private-Function { <#this is a test#> }" | Out-File $ScriptPath\Test-Module\Source\Private\PrivateFunction.ps1
        "#Testfile" | Out-File $ScriptPath\Test-Module\Source\Tests\test.ps1
        $Module = @"
Function Test1 {
	#requires -Version 3.0
    #this is a test function
}

   Function Test2
{
    #Test function 2
}
#Function Get-It {
    #test function 3
#}
#   Function Save-it
{
}
Function Get-Me{
}

Function check-me { <#this is a test#> }
Function check-m2e{ <#this is a test#> }
"@
        $Module | Out-File $ScriptPath\Test-Module\Source\Public\PublicFunction.ps1
        $Class = @"
Class TestBuild
{
    [string]`$test
}
"@
        $Class | Out-File $ScriptPath\Test-Module\Source\Classes\Class.ps1 
        "This is a <template> file to be included in the module" | Out-File $ScriptPath\Test-Module\Source\Includes\en-US\test.xml      
        Start-Sleep -Milliseconds 500

        It "Initial Build without include.txt" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -Include "Source\Includes" } | Should Not Throw
        }
        It "Manifest exists" {
            Test-Path $ScriptPath\Test-Module\Test-Module.psd1 | Should Be True
        }
        It "Module exists" {
            Test-Path $ScriptPath\Test-Module\Test-Module.psm1 | Should Be True
        }
        It "Correct functions were exported" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "FunctionsToExport = 'Test1', 'Test2', 'Get-Me', 'check-me', 'check-m2e'"
            $Search.Count | Should Be 1
        }
        It "PowerShellVersion set to 3.0" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "PowerShellVersion = '3.0'"
            $Search.Count | Should Be 1
        }
        It "Module Version set to 1.0" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '1.0'"
            $Search.Count | Should Be 1
        }
        It "Private function exists in module" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Function Private-Function { <#this is a test#> }"
            $Search.Count | Should Be 1
        }
        It "Spot check public function" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Function check-me { <#this is a test#> }"
            $Search.Count | Should Be 1
        }
        It "Include.txt is not present" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "#Include.txt"
            $Search | Should BeNullOrEmpty
        }
        It "Class exists in module file" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Class TestBuild"
            $Search.Count | Should Be 1
        }
        It "Class should be first" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Class TestBuild"
            $Search.LineNumber | Should Be 1
        }
        It "FunctionsToExport is populated" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "FunctionsToExport = 'Test1', 'Test2', 'Get-Me', 'check-me', 'check-m2e'"
            $Search.Count | Should Be 1
        }
        It "en-US folder present" {
            $Search = Test-Path -Path $ScriptPath\Test-Module\en-US
            $Search | Should Be $true
        }
        It "test.xml is present" {
            $Search = Test-Path -Path $ScriptPath\Test-Module\en-US\test.xml
            $Search | Should Be $true
        }
        It "test.xml was properly copied" {
            $Search = Get-Content -Path $ScriptPath\Test-Module\en-US\test.xml
            $Search | Should Be "This is a <template> file to be included in the module"
        }
    }
    
    Context "Initial Build with include.txt" {
        "#Include.txt" | Out-File $ScriptPath\Test-Module\Source\include.txt
        Remove-Item $ScriptPath\Test-Module\Test-Module.psm1
        Remove-Item $ScriptPath\Test-Module\Test-Module.psd1

        It "Build with include.txt" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module } | Should Not Throw
        }
        It "Include.txt exists in module file" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "#Include.txt"
            $Search.Count | Should Be 1
        }
        It "Include.txt is the first line" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "#Include.txt"
            $Search.LineNumber | Should Be 1
        }
        It "Class should be next after Include.txt" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Class TestBuild"
            $Search.LineNumber | Should Be 3
        }
    }

    Context "Update existing build" {
        $Module = @"
Function Test1 {
    #this is a test function
}
Function Test2
{
    #Test function 2
}
"@
        $Module | Out-File $ScriptPath\Test-Module\Source\Public\PublicFunction.ps1
        Start-Sleep -Milliseconds 500
        It "Update Build" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module } | Should Not Throw
        }
        It "Manifest exists" {
            Test-Path $ScriptPath\Test-Module\Test-Module.psd1 | Should Be True
        }
        It "Module exists" {
            Test-Path $ScriptPath\Test-Module\Test-Module.psm1 | Should Be True
        }
        It "Should only be 2 functions now" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "FunctionsToExport = 'Test1', 'Test2'"
            $Search.Count | Should Be 1
        }
        It "PowerShellVersion set to 3.0" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "PowerShellVersion = '3.0'"
            $Search.Count | Should Be 1
        }
        It "Module Version set to 1.1" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '1.1'"
            $Search.Count | Should Be 1
        }
        It "Private function exists in module" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Function Private-Function { <#this is a test#> }"
            $Search.Count | Should Be 1
        }
        It "Spot check public function" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "Function Test1 {"
            $Search.Count | Should Be 1
        }
        It "Include.txt exists in module file" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psm1 -Pattern "#Include.txt"
            $Search.Count | Should Be 1
        }
    }
    Context "Automatic Version increments" {
        It "Update Build - No version increment" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -IncrementVersion None } | Should Not Throw
        }
        It "ModuleVersion still 1.1" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '1.1'"
            $Search.Count | Should Be 1
        }
        It "Update Build - increment revision, when build and revision don't exist" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -IncrementVersion Revision } | Should Not Throw
        }
        It "ModuleVersion set to 1.1.0.1" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '1.1.0.1'"
            $Search.Count | Should Be 1
        }
        It "Update Build - increment Major" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -IncrementVersion Major } | Should Not Throw
        }
        It "ModuleVersion set to 2.1.0.1" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '2.1.0.1'"
            $Search.Count | Should Be 1
        }
        It "Update Build - increment Minor" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -IncrementVersion Minor } | Should Not Throw
        }
        It "ModuleVersion set to 2.2.0.1" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '2.2.0.1'"
            $Search.Count | Should Be 1
        }
        It "Update Build - increment Build" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -IncrementVersion Build } | Should Not Throw
        }
        It "ModuleVersion set to 2.2.1.1" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '2.2.1.1'"
            $Search.Count | Should Be 1
        }
        It "Update Build - increment Revision" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -IncrementVersion Revision } | Should Not Throw
        }
        It "ModuleVersion set to 2.2.1.2" {
            $Search = Select-String -Path $ScriptPath\Test-Module\Test-Module.psd1 -Pattern "ModuleVersion = '2.2.1.2'"
            $Search.Count | Should Be 1
        }
    }
    Context "Specify Module Name build" {
        It "Update Build" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -ModuleName MyModule } | Should Not Throw
        }
        It "Manifest exists" {
            Test-Path $ScriptPath\Test-Module\MyModule.psd1 | Should Be True
        }
        It "Module exists" {
            Test-Path $ScriptPath\Test-Module\MyModule.psm1 | Should Be True
        }
        It "Correct functions were exported" {
            $Search = Select-String -Path $ScriptPath\Test-Module\MyModule.psd1 -Pattern "FunctionsToExport = 'Test1', 'Test2'"
            $Search.Count | Should Be 1
        }
        It "PowerShellVersion set to 2.0" {
            $Search = Select-String -Path $ScriptPath\Test-Module\MyModule.psd1 -Pattern "PowerShellVersion = '2.0'"
            $Search.Count | Should Be 1
        }
        It "Private function exists in module" {
            $Search = Select-String -Path $ScriptPath\Test-Module\MyModule.psm1 -Pattern "Function Private-Function { <#this is a test#> }"
            $Search.Count | Should Be 1
        }
        It "Spot check public function" {
            $Search = Select-String -Path $ScriptPath\Test-Module\MyModule.psm1 -Pattern "Function Test1 {"
            $Search.Count | Should Be 1
        }
        It "Include.txt exists in module file" {
            $Search = Select-String -Path $ScriptPath\Test-Module\MyModule.psm1 -Pattern "#Include.txt"
            $Search.Count | Should Be 1
        }
    }
    Context "Use Passthru parameter build" {
        It "Update Build with Passthru" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -Passthru | Export-Clixml $ScriptPath\Test-Module\Result.xml } | Should Not Throw
        }
        $Result = Import-Clixml $ScriptPath\Test-Module\Result.xml
        It "Module name is ""Test-Module""" {
            $Result.Name | Should Be "Test-Module"
        }
        It "Source Path is ""$ScriptPath\Test-Module""" {
            $Result.SourcePath | Should Be "$ScriptPath\Test-Module"
        }
        It "ManifestPath is ""$ScriptPath\Test-Module\Test-Module.psd1""" {
            $Result.ManifestPath | Should Be "$ScriptPath\Test-Module\Test-Module.psd1"
        }
        It "ModulePath is ""$ScriptPath\Test-Module\Test-Module.psm1""" {
            $Result.ModulePath | Should Be "$ScriptPath\Test-Module\Test-Module.psm1"
        }
        It "Should be 2 public functions" {
            $Result.PublicFunctions.Count | Should Be 2
        }
        It "Should be 1 private function" {
            $Result.PrivateFunctions.Count | Should Be 1
        }
    }
    Context "Create module in two locations" {
        It "Build with 2 target paths" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module -TargetPath "$ScriptPath\Test-Module","$ScriptPath\Test-Module\Location2" } | Should Not Throw
        }
        It "Module file Exists in location 1" {
            Test-Path $ScriptPath\Test-Module\Test-Module.psm1 | Should Be True
        }
        It "Manifest file Exists in location 1" {
            Test-Path $ScriptPath\Test-Module\Test-Module.psd1 | Should Be True
        }
        It "Module file Exists in locations 2" {
            Test-Path $ScriptPath\Test-Module\Location2\Test-Module.psm1 | Should Be True
        }
        It "Manifest file Exists in locations 2" {
            Test-Path $ScriptPath\Test-Module\Location2\Test-Module.psd1 | Should Be True
        }
    }
    Context "Duplicate function name build" {
        $Module = @"
Function Test1 {
    #this is a test function
}
Function Test1
{
    #Duplicate Function Name
}
"@
        $Module | Out-File $ScriptPath\Test-Module\Source\Public\PublicFunction.ps1
        Start-Sleep -Milliseconds 500
        It "Duplicate function name build should fail" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module } | Should Throw
        }
    }
    Context "Error in function build" {
        $Module = @"
Function Test1 {
    #this is a test function
}
Function Test2
{
    If ($Something
    {
        $Something ++
    }
}
"@
        $Module | Out-File $ScriptPath\Test-Module\Source\Public\PublicFunction.ps1
        It "Error in function Test2 should fail" {
            { Invoke-PSModuleBuild -Path $ScriptPath\Test-Module } | Should Throw
        }
    }
}

#Clean up!
Start-Sleep -Milliseconds 500
Remove-Item $ScriptPath\Test-Module -Recurse -Force -ErrorAction SilentlyContinue