Properties {
    $PublishInformation = @{
        Path            = "$ENV:APPVEYOR_BUILD_FOLDER\PSModuleBuild"
        Force           = $true
        NuGetApiKey     = $ENV:PSGalleryAPIKey
    }

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
    }
}


Task Default -Depends Test,Deploy

Task Init {
    Set-Location $ENV:APPVEYOR_BUILD_FOLDER
}

Task Analyze -Depends Init {
    $Results = Invoke-ScriptAnalyzer -Path $ENV:APPVEYOR_BUILD_FOLDER -Severity "Error" -Recurse
    If ($Results) 
    {
        $Results | Format-Table  
        Write-Error "One or more Script Analyzer errors/warnings where found. Build cannot continue!"
    }
}

Task Build -Depends Analyze {
    Invoke-PSModuleBuild @ModuleInformation
}

Task Test -Depends Build  {
    # Gather test results. Store them in a variable and file
    $TestResults = Invoke-Pester -PassThru -OutputFormat NUnitXml -OutputFile ".\TestResults.xml"
    (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",(Resolve-Path ".\TestResults.xml"))
    
    If ($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed" -ErrorAction Stop
    }
}

Task Deploy -Depends Test -Precondition { $ENV:APPVEYOR_FORCED_BUILD -eq "True" } {
    Try {
        Publish-Module @PublishInformation -ErrorAction Stop
        Write-Host "Publish to PSGallery successful" -ForegroundColor Green
    }
    Catch {
        Write-Error "Publish to PSGallery failed because ""$_""" -ErrorAction Stop
    }
}