################################################################################
##  File:  Configure-User.ps1
##  Desc:  Performs user part of warm up and moves data to C:\Users\Default
################################################################################

#
# more: https://github.com/actions/runner-images-internal/issues/5320
#       https://github.com/actions/runner-images/issues/5301#issuecomment-1648292990
#

$warmupStart = Get-Date
Write-Host "Warmup 'devenv.exe /updateconfiguration'"
$vsInstallRoot = (Get-VisualStudioInstance).InstallationPath
$devEnvPath = "$vsInstallRoot\Common7\IDE\devenv.exe"

& "$devEnvPath" /RootSuffix Exp /ResetSettings General.vssettings /Command File.Exit | Out-Null
cmd.exe /c "`"$vsInstallRoot\Common7\IDE\devenv.exe`" /updateconfiguration"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to warmup 'devenv.exe /updateconfiguration'"
}

$warmupVdproj = $(Join-Path "C:\post-generation" "warmup.vdproj")
& "$devEnvPath" $warmupVdproj /build Release | Out-Null

$warmupFinish = Get-Date
$warmupTime = "$(($warmupFinish - $warmupStart).Minutes):$(($warmupFinish - $warmupStart).Seconds)"
Write-Host "The process took a total of $warmupTime (in minutes:seconds)"

# we are fine if some file is locked and cannot be copied
Copy-Item ${env:USERPROFILE}\AppData\Local\Microsoft\VisualStudio -Destination c:\users\default\AppData\Local\Microsoft\VisualStudio -Recurse -ErrorAction SilentlyContinue
Copy-Item ${env:USERPROFILE}\AppData\Local\Microsoft\VSCommon -Destination c:\users\default\AppData\Local\Microsoft\VSCommon -Recurse -ErrorAction SilentlyContinue
Copy-Item ${env:USERPROFILE}\AppData\Local\AzureFunctionsTools -Destination c:\users\default\AppData\Local\AzureFunctionsTools -Recurse -ErrorAction SilentlyContinue
Copy-Item ${env:USERPROFILE}\AppData\Roaming\Microsoft\VisualStudio -Destination c:\users\default\AppData\Roaming\Microsoft\VisualStudio -Recurse -ErrorAction SilentlyContinue

$RegKeys = @(
    "HKCU\AppEvents\EventLabels\VS_BreakpointHit",
    "HKCU\AppEvents\EventLabels\VS_BuildCanceled",
    "HKCU\AppEvents\EventLabels\VS_BuildFailed",
    "HKCU\AppEvents\EventLabels\VS_BuildSucceeded",
    "HKCU\AppEvents\Schemes\Apps\devenv",
    "HKCU\Software\Microsoft\Avalon.Graphics\IgnoreDwmFlushErrors",
    "HKCU\Software\Microsoft\DevDiv",
    "HKCU\Software\Microsoft\DeveloperTools",
    "HKCU\Software\Microsoft\SQMClient",
    "HKCU\Software\Microsoft\VisualStudio",
    "HKCU\Software\Microsoft\VSCommon"
)

$finalRegKeys = @("Windows Registry Editor Version 5.00")

Foreach ($key in $regKeys) {
    $exportFileName = "$($key.Split('\')[-1]).reg"
    $exportFilePath = $(Join-Path $env:TEMP_DIR $exportFileName)
    & reg export $key $exportFilePath /y
    $fileContent = Get-Content -Path $exportFilePath
    for ($i = 1; $i -le $fileContent.Count; $i += 1) {
        if (-not[string]::IsNullOrEmpty($fileContent[$i])) {
            $finalRegKeys += $fileContent[$i].Replace('HKEY_CURRENT_USER','HKEY_LOCAL_MACHINE\DEFAULT')
        }
    }
}
Set-Content -Path $(Join-Path $env:TEMP_DIR "finalregfile.reg") -Value $finalRegKeys

Mount-RegistryHive `
    -FileName "C:\Users\Default\NTUSER.DAT" `
    -SubKey "HKLM\DEFAULT"

reg.exe copy HKCU\Software\Microsoft\VisualStudio HKLM\DEFAULT\Software\Microsoft\VisualStudio /s
if ($LASTEXITCODE -ne 0) {
    throw "Failed to copy HKCU\Software\Microsoft\VisualStudio to HKLM\DEFAULT\Software\Microsoft\VisualStudio"
}

& reg import $(Join-Path $env:TEMP_DIR "finalregfile.reg")
if ($LASTEXITCODE -ne 0) {
    throw "Failed to import $(Join-Path $env:TEMP_DIR"finalregfile.reg") file to HKLM\DEFAULT"
}

# TortoiseSVN not installed on Windows 2025 image due to Sysprep issues
if (-not (Test-IsWin25)) {
    # disable TSVNCache.exe
    $registryKeyPath = 'HKCU:\Software\TortoiseSVN'
    if (-not(Test-Path -Path $registryKeyPath)) {
        New-Item -Path $registryKeyPath -ItemType Directory -Force
    }

    New-ItemProperty -Path $registryKeyPath -Name CacheType -PropertyType DWORD -Value 0
    reg.exe copy HKCU\Software\TortoiseSVN HKLM\DEFAULT\Software\TortoiseSVN /s
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy HKCU\Software\TortoiseSVN to HKLM\DEFAULT\Software\TortoiseSVN"
    }
}
# Accept by default "Send Diagnostic data to Microsoft" consent.
if (Test-IsWin25) {
    $registryKeyPath = 'HKLM:\DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'
    New-ItemProperty -Path $registryKeyPath -Name PrivacyConsentPresentationVersion -PropertyType DWORD -Value 3 | Out-Null
    New-ItemProperty -Path $registryKeyPath -Name PrivacyConsentSettingsValidMask -PropertyType DWORD -Value 4 | Out-Null
    New-ItemProperty -Path $registryKeyPath -Name PrivacyConsentSettingsVersion -PropertyType DWORD -Value 5 | Out-Null
}

Dismount-RegistryHive "HKLM\DEFAULT"

# Remove the "installer" (var.install_user) user profile for Windows 2025 image
if (Test-IsWin25) {
    Get-CimInstance -ClassName Win32_UserProfile | where-object {$_.LocalPath -match $env:INSTALL_USER} | Remove-CimInstance -Confirm:$false
    & net user $env:INSTALL_USER /DELETE
}

Write-Host "Configure-User.ps1 - completed"
