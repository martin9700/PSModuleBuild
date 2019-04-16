$ScriptPath = $ENV:APPVEYOR_BUILD_FOLDER
#Non-appveyor testing
#$ScriptPath = "c:\dropbox\github\PSModuleBuild"
. $ScriptPath\Source\Public\Invoke-PSModuleBuild.ps1
. $ScriptPath\Source\Private\CreateUpdateManifest.ps1

$ModuleInformation = @{
    Path            = "$ENV:APPVEYOR_BUILD_FOLDER\Source"
    TargetPath      = "$ENV:APPVEYOR_BUILD_FOLDER\PSModuleBuild"
    ModuleName      = "PSModuleBuild"
    ReleaseNotes    = "Fix"
    Author          = "Martin Pugh (@TheSurlyAdm1n)"
    ModuleVersion   = "1.2.9"
    Company         = "www.thesurlyadmin.com"
    Description     = "Easily build a PowerShell module and manifest from a set of functions contained in individual PS1 files"
    ProjectURI      = "https://github.com/martin9700/PSModuleBuild"
    LicenseURI      = "https://github.com/martin9700/PSModuleBuild/blob/master/LICENSE"
    IconURI         = "https://pughspace.files.wordpress.com/2017/01/pspublishmodule-icon.png"
    PassThru        = $true
}

#Using my module to build and test my module. The irony is not lost
Invoke-PSModuleBuild @ModuleInformation

$PublishInformation = @{
    Path            = "c:\Dropbox\PSModuleBuild"
    Force           = $true
    NuGetApiKey     = $ENV:PSGalleryAPIKey
}
Publish-Module @PublishInformation