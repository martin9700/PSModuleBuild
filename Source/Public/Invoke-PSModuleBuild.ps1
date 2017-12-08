Function Invoke-PSModuleBuild {

    <#
    .SYNOPSIS
        Easily build PowerShell modules for a set of functions contained in individual PS1 files

    .DESCRIPTION
        Creating a PowerShell module can be hard, and maintaining it can be even harder.  PSModuleBuild has been designed to make
        both tasks easier.  In short, you put all of your advanced functions into individual .ps1 files and then invoke PSModuleBuild
        and let it collect all the functions into a PowerShell module file (.psm1) and create the PowerShell module manifest
        file (.psd1).

        Files can be excluded from processing by putting these keywords in their name:
            exclude
            tests
            psake\.ps1
            ^build\.ps1$
            \.psdeploy\.

        Public and private functions are also support by creating the proper folder structure:

        \Source
           \Public
           \Private

        If you have any scripts or cmdlets that need to be run at Import-Module time, you can put them in an Include.txt
        file and PSModuleBuild will read this file first and put it in the module file first.  This is not strictly needed
        as PSModuleBuild will read in all .ps1 files and put them in but if you'd like to make sure these commands are run at
        the beginning of the file you can.


    .PARAMETER Path
        The path where you module folders and PS1 files containing your functions is located.

    .PARAMETER TargetPath
        The path where you want the module and manifest files to be located. If the folder does not exist Invoke-PSModuleBuild will create it, if
        it is not designated it will use the Path location.  Multiple folder paths can be designated as well if you want to deploy to multiple
        locations.

    .PARAMETER ModuleName
        What you want to call your module. By default the module will be named after the folder you point
        to in Path.

    .PARAMETER Passthru
        Will produce an object with information about the newly created module

    .PARAMETER ReleaseNotes
        Any release notes you want to include in the module manifest.  If a manifest file already exists Invoke-PSModuleBuild will
        read the release notes from it and join the new release notes together.

    .PARAMETER IncrementVersion
        If a previous manifest file is located, PSModuleBuild will automatically increment the version number (unless you set this parameter to
        "None").  Set which field you want to increment "major", "minor", "build" or "revision" or set it to "last" and it will increment the last
        field that previous existed.  For example:

        1.1 would become 1.2
        1.0.0.3 would become 1.0.0.4

        Default settings is "Last"

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
        1.0.15          Updated comment based help
        1.1             Added multiple target paths
        1.1.38          Fixed bug with release notes. Added IncrementVersion
    .LINK
        https://github.com/martin9700/PSModuleBuild
    #>
    [CmdletBinding()]
    Param (
        [ValidateScript({ Test-Path $_ })]
        [string]$Path,
        [string[]]$TargetPath,
        [string]$ModuleName,
        [switch]$Passthru,
        [string[]]$ReleaseNotes,
        [ValidateSet("None","Last","Major","Minor","Build","Revision")]
        [string]$IncrementVersion = "Last"
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

    END {
        Write-Verbose "$(Get-Date): Invoke-PSModuleBuild started"

        If (-not $Path)
        {
            $Path = $PSScriptRoot
        }

        If ($TargetPath)
        {
            ForEach ($TP in $TargetPath)
            {
                If (-not (Test-Path $TP))
                {
                    New-Item -Path $TP -ItemType Directory
                }
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
        $NewManifest = @{}
        

        ForEach ($Key in ($PSBoundParameters.GetEnumerator() | Where { $_.Key -NotMatch "Path|Passthru|ModuleName|IncrementVersion" -and $CommonParams -notcontains $_.Key }))
        {
            $NewManifest.Add($Key.Key,$Key.Value)
        }
        ForEach ($TP in $TargetPath)
        {
            #Save the manifest
            $ManifestPath = Join-Path -Path $TP -ChildPath "$ModuleName.psd1"
            $ResultManifest = CreateUpdateManifest -Manifest $NewManifest.Clone() -OldManifestPath $ManifestPath

            #Save the module file
            $ModulePath = Join-Path -Path $TP -ChildPath "$ModuleName.psm1"
            $Module | Out-File $ModulePath -Encoding ascii
            Write-Verbose "Module created at: $TP as $ModuleName" -Verbose

            #Passthru
            If ($Passthru)
            {
                [PSCustomObject]@{
                    Name             = $ModuleName
                    SourcePath       = $Path
                    TargetPath       = $TargetPath
                    ManifestPath     = $ManifestPath
                    ModulePath       = $ModulePath
                    ModuleVersion    = $ResultManifest.ModuleVersion
                    RequiredVersion  = $ResultManifest.PowerShellVersion
                    PublicFunctions  = @($FunctionNames | Where Private -eq $false | Select -ExpandProperty Name)
                    PrivateFunctions = @($FunctionNames | Where Private -eq $true | Select -ExpandProperty Name)
                    ReleaseNotes     = $ResultManifest.ReleaseNotes
                }
            }
        }

        Write-Verbose "$(Get-Date): Invoke-PSModuleBuild completed."
    }
}
