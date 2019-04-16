Function CreateUpdateManifest
{
    [CmdletBinding()]
    Param (
        [hashtable]$Manifest,
        [string]$OldManifestPath,
        [System.Collections.ArrayList]$FunctionNames
    )

    If (Test-Path $OldManifestPath)
    {
        $OldManifest = Import-LocalizedData -BaseDirectory (Split-Path $OldManifestPath) -FileName (Split-Path $OldManifestPath -Leaf)
        If ([version]$OldManifest.PowerShellVersion -gt $HighVersion)
        {
            $HighVersion = [version]$OldManifest.PowerShellVersion
        }
        If ($Manifest.PowerShellVersion -gt $HighVersion)
        {
            $HighVersion = $Manifest.PowerShellVersion
        }
        $Manifest.ReleaseNotes = $ReleaseNotes + $OldManifest.PrivateData.PSData.ReleaseNotes
        $Manifest.Path = $OldManifestPath
        $Manifest.PowerShellVersion = $HighVersion
        $Manifest.FunctionsToExport = $FunctionNames | Where Private -eq $false | Select -ExpandProperty Name
        If (-not $Manifest.ModuleVersion)
        {
            $VersionNum = [ordered]@{}
            $VersionFields = "Major","Minor","Build","Revision"
            $Count = 0
            ForEach ($VersionField in $VersionFields)
            {
                $VersionNum.Add($VersionField,$Count)
                $Count ++
            }
            Try {
                $OldModuleVersion = [version]$OldManifest.ModuleVersion
            }
            Catch {}
            If ($OldModuleVersion -is [version])
            {
                $Versions = @()
                ForEach ($Num in (0..3))
                {
                    $VF = $VersionFields[$Num]
                    If ($OldModuleVersion.$VF -lt 0 -and $VersionNum[$IncrementVersion] -gt $VersionNum[$Num])
                    {
                        $Versions += 0
                    }
                    ElseIf ($OldModuleVersion.$VF -lt 0 -and $IncrementVersion -eq $VF)
                    {
                        $Versions += 1
                    }
                    ElseIf ($OldModuleVersion.$VF -ge 0)
                    {
                        If ($VF -eq $IncrementVersion)
                        {
                            $Versions += $OldModuleVersion.$VF + 1
                        }
                        Else
                        {
                            $Versions += $OldModuleVersion.$VF
                        }
                    }
                }
                If ($IncrementVersion -eq "Last")
                {
                    $Versions[-1] ++
                }
                $Manifest.ModuleVersion = $Versions -join "."
            }
        }

        Update-ModuleManifest @Manifest
    }
    Else
    {
        $Manifest.RootModule = $ModuleName
        $Manifest.Path = $OldManifestPath
        $Manifest.PowerShellVersion = "$($HighVersion.Major).$($HighVersion.Minor)"
        $Manifest.FunctionsToExport = $FunctionNames | Where Private -eq $false | Select -ExpandProperty Name
        If ($ReleaseNotes)
        {
            $Manifest.ReleaseNotes = $ReleaseNotes | Out-String
        }
        New-ModuleManifest @Manifest
    }

    Return $Manifest
}