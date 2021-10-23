[String] $envAppDataJetBrains = "$Env:APPDATA\JetBrains"
[String] $jetBrainsProducts = "Idea|GoLand|CLion|PyCharm|DataGrip|RubyMine|AppCode|PhpStorm|WebStorm|Rider"
[Array]  $jetBrainsProductsList = $jetBrainsProducts.Split("|")
[String] $jetBrainsProductsRegex = "\.?($jetBrainsProducts).*"
[String] $HKCU_jetbrains = "HKCU:\SOFTWARE\JavaSoft\Prefs\jetbrains\" #HKEY_CURRENT_USER\SOFTWARE\JavaSoft\Prefs\jetbrains\

$jetBrainsProductElemList = New-Object System.Collections.ArrayList

class PathUtils {
    static [Boolean] ItemExist($ItemPath) {
        $path = Test-Path -Path $ItemPath
        if ($path -eq $true) {
            return $true
        } else {
            return $false
        }
    }

    static [Boolean] RemoveItem($ItemPath) {
        try {
            Remove-Item $ItemPath
            return $true
        }
        catch {
            return $false
        }
    }
}

class JetBrainsProductElem {
    hidden [System.IO.DirectoryInfo] $Folder
    hidden [System.IO.DirectoryInfo] $EvalForlder
    hidden [System.IO.DirectoryInfo] $OptionsFolder
    hidden [System.IO.DirectoryInfo] $OtherXMLOptions
    hidden [String] $RegistryKey

    JetBrainsProductElem([System.IO.DirectoryInfo]$folder,  [String] $registryKey) {
        $this.Folder = $folder
        $this.EvalForlder = $folder.FullName + "\eval"
        $this.OptionsFolder = $folder.FullName + "\options"
        $this.OtherXMLOptions = $this.OptionsFolder.FullName + "\other.xml"
        $this.RegistryKey = $registryKey

        Write-Host " $($this.Folder)`t`t" -ForegroundColor Yellow
    }

    [void] hidden DeleteEvalForlder() {
        if ([PathUtils]::ItemExist($this.EvalForlder)) {
            if ([PathUtils]::RemoveItem($this.EvalForlder)) {
                Write-Host "Remove completed" -ForegroundColor Green
            } else {
                Write-Host "OH NO! We can't remove this item - $($this.EvalForlder)" -ForegroundColor Red
            }
        } else {
            Write-Host "No eval folder" -ForegroundColor Green
        }
    }

    [void] hidden ChangeOtherXMLFile() {
        if ([PathUtils]::ItemExist($this.OtherXMLOptions)) {
            $SEL = Select-String -Path $this.OtherXMLOptions -Pattern '<property name="evlsprt\d.*$'

            if ($SEL -ne $null) {
                (Get-Content $this.OtherXMLOptions) | Foreach-Object {$_ -replace '<property name="evlsprt\d.*$', $null} | Set-Content $this.OtherXMLOptions
                Write-Host "Edit other.xml completed" -ForegroundColor Green
            } else {
                Write-Host "No evlsprt in file" -ForegroundColor Green
            }
        } else {
            Write-Host "No other.xml file" -ForegroundColor Green
        }
    }

    [void] hidden RemoveRegistryItems() {
        if ( ! $this.RegistryKey.Equals("HKCU:\SOFTWARE\JavaSoft\Prefs\jetbrains\") -and [PathUtils]::ItemExist($this.RegistryKey)) {
            if ([PathUtils]::RemoveItem($this.RegistryKey)) {
                Write-Host "Remove completed" -ForegroundColor Green
            } else {
                Write-Host "OH NO! We can't remove this item - $($this.RegistryKey)" -ForegroundColor Red
            }
        } else {
            Write-Host "No eval register key" -ForegroundColor Green
        }

    }

    [void] eval() {
        Write-Host " Eval $($this.Folder)`t`t" -ForegroundColor Yellow

        $this.DeleteEvalForlder()
        $this.ChangeOtherXMLFile()
        $this.RemoveRegistryItems()

        Write-Host "`n" -ForegroundColor Yellow
    }

    [string] ToString(){
        #        return ("{0} | {1}" -f $this.Folder.FullName, $this.EvalForlder, $this.OptionsFolder)
        return ("{0}" -f $this.Folder.FullName)
    }
}



function FindAllFoldersFromRegexAndFolderPath($folder) {
    return Get-ChildItem -Path $folder | Where-Object { $_.Name -match $jetBrainsProductsRegex }
}
function IsJetBrainsProductsListContainsRegexFolder($regexFolder) {
    foreach ($jetBrainsProduct in $jetBrainsProductsList) {
        if ($regexFolder.FullName.Contains($jetBrainsProduct)) {
            return $true
        }
    }
}
function GetEvlsprtRegistryKeysFromPath($path) {
    return Get-ChildItem -Recurse -Path $path | Where-Object { $_.Name -match '\\evlsprt\d*' }
}
function GetRegistryKey($regexFolder) {
    $registryKeys = GetEvlsprtRegistryKeysFromPath($HKCU_jetbrains)
    foreach ($registryItem in $registryKeys) {
        [Array] $itemName = $registryItem.Name.Split("\")

        if ($regexFolder.FullName -like "*$($itemName[5])*") {
            return $itemName[5..($itemName.Length-2)] -join "\"
        }
    }

    return $null
}

function FindAllJetBrainsProductElems($folder) {
    $foldersFromRegex = FindAllFoldersFromRegexAndFolderPath($folder)

    foreach ($regexFolder in $foldersFromRegex) {
        if (IsJetBrainsProductsListContainsRegexFolder($regexFolder)) {
            [String]$registryKey = GetRegistryKey($regexFolder)

            [JetBrainsProductElem]$result = [JetBrainsProductElem]::new($regexFolder, $HKCU_jetbrains + $registryKey)
        }

        $jetBrainsProductElemList.Add($result) | Out-Null
    }

}
function PromtEval() {
    $reply = Read-Host -Prompt "`r`nEval them all? [y/n]"

    if ($reply -match "[yY]") {
        return $true
    }

    return $false
}
function Eval() {
    Write-Host "`r`n"
    Write-Host "Eval folders: `n"

    foreach ($jetBrainsProduct in $jetBrainsProductElemList) {
        $jetBrainsProduct.eval()
    }
}

function main {

    [String] $defaultFolder = $envAppDataJetBrains

    if ([PathUtils]::ItemExist($defaultFolder)) {
        Write-Host "`n`n`n`n`n+ Your default folder($defaultFolder) was find!`n" -ForegroundColor Green

        FindAllJetBrainsProductElems($defaultFolder)
        Write-Host " `nFound $(($jetBrainsProductElemList).count) JetBrains folders" -ForegroundColor Yellow

        if ($jetBrainsProductElemList.count -gt 0) {
            if (PromtEval) {
                Eval
            }
        }
    }

    Write-Host "`n`n"
}

main