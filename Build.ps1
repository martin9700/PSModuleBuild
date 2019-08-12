Write-Verbose -Verbose -Message "$(Get-Date): Preparing environment"
$Stopwatch = [system.diagnostics.stopwatch]::StartNew()

# Grab nuget bits, install modules, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

#Now PSGallery
Import-Module PowerShellGet -ErrorAction Stop
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module Pester,PSScriptAnalyzer,PSModuleBuild


#
#Analyse source
#
Write-Verbose -Verbose -Message "$(Get-Date): Analyzing code"
Set-Location $ENV:APPVEYOR_BUILD_FOLDER

Import-Module PSScriptAnalyzer
$Results = Invoke-ScriptAnalyzer -Path $ENV:APPVEYOR_BUILD_FOLDER -Severity "Error" -Recurse
If ($Results) 
{
    $Results | Format-Table  
    Write-Error "One or more Script Analyzer errors/warnings where found. Build cannot continue!" -ErrorAction Stop
}


#
#Build
#
Write-Verbose -Verbose -Message "$(Get-Date): Building module" 
$ModuleInformation = @{
    Path            = "$ENV:APPVEYOR_BUILD_FOLDER\Source"
    TargetPath      = "$ENV:APPVEYOR_BUILD_FOLDER\PSModuleBuild"
    ModuleName      = "PSModuleBuild"
    ReleaseNotes    = (git log -1 --pretty=%s) | Out-String
    Author          = "Martin Pugh (@TheSurlyAdm1n)"
    ModuleVersion   = $ENV:APPVEYOR_BUILD_VERSION
    Company         = "www.thesurlyadmin.com"
    Description     = "Easily build a PowerShell module and manifest from a set of functions contained in individual PS1 files"
    ProjectURI      = "https://github.com/martin9700/PSModuleBuild"
    LicenseURI      = "https://github.com/martin9700/PSModuleBuild/blob/master/LICENSE"
    IconURI         = "https://pughspace.files.wordpress.com/2017/01/pspublishmodule-icon.png"
    PassThru        = $true
    Include         = "Includes"
}

#Using my module to build and test my module. The irony is not lost
Import-Module PSModuleBuild
Invoke-PSModuleBuild @ModuleInformation


#
# Test
#
Write-Verbose -Verbose -Message "$(Get-Date): Running tests"
Import-Module Pester

$TestResults = Invoke-Pester -PassThru -OutputFormat NUnitXml -OutputFile ".\TestResults.xml"
(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",(Resolve-Path ".\TestResults.xml"))
    
If ($TestResults.FailedCount -gt 0)
{
    Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed" -ErrorAction Stop
}


#
# Deploy
#
If ($ENV:PSGalleryAPIKey)
{
    Write-Verbose -Verbose -Message "$(Get-Date): Merge detected, publishing to PSGallery"
    $PublishInformation = @{
        Path            = "$ENV:APPVEYOR_BUILD_FOLDER\PSModuleBuild"
        Force           = $true
        NuGetApiKey     = $ENV:PSGalleryAPIKey
    }

    Try {
        Publish-Module @PublishInformation -ErrorAction Stop
        Write-Host "Publish to PSGallery successful" -ForegroundColor Green
    }
    Catch {
        Write-Error "Publish to PSGallery failed because ""$_""" -ErrorAction Stop
    }
}

#
# Completed
#
$Stopwatch.Stop()
Write-Verbose -Verbose -Message "$(Get-Date): Build completed in $($Stopwatch.Elapsed)"
