Function Invoke-PSModuleBuild {

    <#
    .SYNOPSIS
        Easily build PowerShell modules for a set of functions contained in individual PS1 files

    .DESCRIPTION
        Put a collection of your favorite functions into their own PS1 files create a PowerShell module.  The module will 
        be named after the folder name they're placed under. Key folders can be used to specify different file types. Unless
        the path name contains one of the below key names, all functions will be exported by the module and available to the
        user.

        Include.txt - Sometimes you want some code to set the environment for your module, or to do some task.  While not 
                      necessary, if you want the code to appear at the top of the module you can use Include.txt to accomplish
                      this.  Do not place any functions in this file because script will not process it, it just puts it
                      into the module file.

        *Private*   - if Private is in the path name, all functions found in this path will be not be exported and will not
                      be available to the user. However, they will be available as internal functions to the module.
        *Exclude*   - any files found with Exclude in the path name will not be included in the module at all.
        *Tests*     - any files found with Tests in the path name will not be included in the module at all (put your Pester
                      tests here).

        Manifest file for the module will also be created with the correct PowerShell version requirement (assuming you
        specified this with the "#requires -Version" code in your functions).

        Manifest file can also be edited to suit your requirements.

    .PARAMETER Path
        The path where you module folders and PS1 files containing your functions is located.

    .PARAMETER ModuleName
        What you want to call your module. By default the module will be named after the folder you point
        to in Path.
    
    .PARAMETER BuildVersion
        Update the ModuleVersion field in the module manifest

    .PARAMETER Passthru
        Will produce an object with information about the newly created module

    .INPUTS
        None
    
    .OUTPUTS
        [PSCustomObject]
    
    .EXAMPLE
        Invoke-PSModuleBuild -Path c:\Test-Module 

        Module will be named Test-Module (.psm1 and .psd1) and will include all functions in that path.

    .EXAMPLE
        Invoke-PSModuleBuild -Path c:\Test-Module -ModuleName Make-GreatStuff -Passthru

        Module will be named Make-GreatStuff.  Returned object will be:

        Name            : Make-GreatStuff
        Path            : c:\Test-Module
        ManifestPath    : c:\Test-Module\Test-Module.psd1
        ModulePath      : c:\Test-Module\Test-Module.psm1
        PublicFunctions : {Test1, Test2}
        PrivateFunctions: {Test3}

    .NOTES
        Author:             Martin Pugh
        Twitter:            @thesurlyadm1n
        Spiceworks:         Martin9700
        Blog:               www.thesurlyadmin.com

        Changelog:
        1.0             Initial Release
        1.0.9           Moved from RegEx to AST for function parsing
        1.0.10          Updated comment based help.  Added Passthru parameter
        1.0.11          Updated comment based help.  Exclude psake.ps1, build.ps1 and .psdeploy. from function import.
                        Added BuildVersion
        1.0.12          Removed BuildVersion.  Added dynamic parameters from New-ModuleManifest.
        1.0.13          Removed a debugging line.
        1.0.14          Rename to Invoke-PSModuleBuild and create module named PSModuleBuild.  Added ReleaseNotes support (New and Update-ModuleManifest treat ReleaseNotes differently)
    .LINK
        https://github.com/martin9700/PSModuleBuild
    #>
    [CmdletBinding()]
    Param (
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        [string]$TargetPath,
        [string]$ModuleName,
        [switch]$Passthru,
        [string[]]$ReleaseNotes
    )
    DynamicParam {
        # Create the dictionary that this scriptblock will return:
        $DynParamDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $CommonParams = [System.Management.Automation.PSCmdlet]::CommonParameters
        $CommonParams += [System.Management.Automation.PSCmdlet]::OptionalCommonParameters           
            
        # Get dynamic params that real Cmdlet would have:
        $Parameters = Get-Command -Name New-ModuleManifest | Select-Object -ExpandProperty Parameters
        ForEach ($Parameter in $Parameters.GetEnumerator()) 
        {
            If ($CommonParams -notcontains $Parameter.Key)
            {
                $DynamicParameter = New-Object System.Management.Automation.RuntimeDefinedParameter (
                    $Parameter.Key,
                    $Parameter.Value.ParameterType,
                    $Parameter.Value.Attributes
                )
                #Added in check to not add Name or NotificationEmail parameters because they are defined in static parameters
                If (-not $DynParamDictionary.ContainsKey($Parameter.Key) -and $Parameter.Key -notmatch "Path|Passthru|ReleaseNotes")
                {
                    $DynParamDictionary.Add($Parameter.Key, $DynamicParameter)
                }
            }
        
        }
        # Return the dynamic parameters
        $DynParamDictionary
    }

    PROCESS {
        Write-Verbose "$(Get-Date): Invoke-PSModuleBuild started"

        If (-not $Path)
        {
            $Path = $PSScriptRoot
        }

        If ($TargetPath)
        {
            If (-not (Test-Path $TargetPath))
            {
                New-Item -Path $TargetPath -ItemType Directory
            }
        }
        Else
        {
            $TargetPath = $Path
        }

        If (-not $ModuleName)
        {
            $ModuleName = Get-ItemProperty -Path $Path | Select -ExpandProperty BaseName
        }

        $Module = New-Object -TypeName System.Collections.ArrayList
        $FunctionNames = New-Object -TypeName System.Collections.ArrayList
        $FunctionPredicate = { ($args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]) }
        $HighVersion = [version]"2.0"

        Write-Verbose "$(Get-Date): Searching for ps1 files and include.txt for module"
        #Retrieve Include.txt file(s)
        $Files = Get-ChildItem $Path\Include.txt -Recurse | Sort FullName
        ForEach ($File in $Files)
        {
            $Raw = Get-Content $File
            $null = $Module.Add($Raw)
        }

        #Retrieve ps1 files
        $Files = Get-ChildItem $Path\*.ps1 -File -Recurse | Where FullName -NotMatch "Exclude|Tests|psake\.ps1|^build\.ps1|\.psdeploy\." | Sort FullName
        ForEach ($File in $Files)
        {
            $Raw = Get-Content $File -Raw
            $Private = $false
            If ($File.DirectoryName -like "*Private*")
            {
                $Private = $true
            }
            $null = $Module.Add($Raw)

            #Parse out the function names
            #Thanks Zachary Loeber
            $ParseError = $null
            $Tokens = $null
            $AST = [System.Management.Automation.Language.Parser]::ParseInput($Raw, [ref]$Tokens, [ref]$ParseError)
            If ($ParseError)
            {
                Write-Error "Unable to parse $($File.FullName) because ""$ParseError""" -ErrorAction Stop
            }

            ForEach ($Name in ($AST.FindAll($FunctionPredicate, $true) | Select -ExpandProperty Name))
            {
                If ($FunctionNames.Name -contains $Name)
                {
                    Write-Error "Your module has duplicate function names: $Name.  Duplicate found in $($File.FullName)" -ErrorAction Stop
                }
                Else
                {
                    $null = $FunctionNames.Add([PSCustomObject]@{
                        Name = $Name
                        Private = $Private
                    })
                }
            }

            If ($AST.ScriptRequirements.RequiredPSVersion -gt $HighVersion)
            {
                $HighVersion = $AST.ScriptRequirements.RequiredPSVersion
            }
        }

        #Create the manifest file
        Write-Verbose "$(Get-Date): Creating/Updating module manifest and module file"
        $Manifest = @{}
        $ManifestPath = Join-Path $TargetPath -ChildPath "$ModuleName.psd1"

        ForEach ($Key in ($PSBoundParameters.GetEnumerator() | Where { $_.Key -NotMatch "Path|Passthru|ModuleName" -and $CommonParams -notcontains $_.Key }))
        {
            $Manifest.Add($Key.Key,$Key.Value)
        }
        If (Test-Path $ManifestPath)
        {
            $OldManifest = Invoke-Expression -Command (Get-Content $ManifestPath -Raw)
            If ([version]$OldManifest.PowerShellVersion -gt $HighVersion)
            {
                $HighVersion = [version]$OldManifest.PowerShellVersion
            }
            If ($OldManifest.PrivateData.PSData.ReleaseNotes)
            {
                $Manifest.ReleaseNotes = $ReleaseNotes + $OldManifest.PrivateData.PSData.ReleaseNotes
            }
            If ($Manifest.PowerShellVersion -gt $HighVersion)
            {
                $HighVersion = $Manifest.PowerShellVersion
            }
            $Manifest.Path = $ManifestPath
            $Manifest.PowerShellVersion = $HighVersion
            $Manifest.FunctionsToExport = $FunctionNames | Where Private -eq $false | Select -ExpandProperty Name
            If ($BuildVersion)
            {
                $Manifest.Add("ModuleVersion",$BuildVersion)
            }
            Update-ModuleManifest @Manifest
        }
        Else
        {
            $Manifest.RootModule = $ModuleName
            $Manifest.Path = $ManifestPath
            $Manifest.PowerShellVersion = "$($HighVersion.Major).$($HighVersion.Minor)"
            $Manifest.FunctionsToExport = $FunctionNames | Where Private -eq $false | Select -ExpandProperty Name
            If ($BuildVersion)
            {
                $Manifest.Add("ModuleVersion",$BuildVersion)
            }
            If ($ReleaseNotes)
            {
                $Manifest.ReleaseNotes = $ReleaseNotes | Out-String
            }
            New-ModuleManifest @Manifest
        }

        #Save the Module file
        $ModulePath = Join-Path -Path $TargetPath -ChildPath "$ModuleName.psm1"
        $Module | Out-File $ModulePath -Encoding ascii

        #Passthru
        If ($Passthru)
        {
            [PSCustomObject]@{
                Name             = $ModuleName
                SourcePath       = $Path
                TargetPath       = $TargetPath
                ManifestPath     = $ManifestPath
                ModulePath       = $ModulePath
                RequiredVersion  = $Manifest.PowerShellVersion
                PublicFunctions  = @($FunctionNames | Where Private -eq $false | Select -ExpandProperty Name)
                PrivateFunctions = @($FunctionNames | Where Private -eq $true | Select -ExpandProperty Name)
                ReleaseNotes     = $ReleaseNotes
            }
        }

        Write-Verbose "Module created at: $Path as $ModuleName" -Verbose
        Write-Verbose "$(Get-Date): Invoke-PSModuleBuild completed."
    }
}
