################################################################################
##  File: Install-WindowsUpdatesAfterReboot.ps1
##  Desc: Waits for Windows Updates to finish installing after reboot
################################################################################

Invoke-ScriptBlockWithRetry -RetryCount 10 -RetryIntervalSeconds 120 -Command {
    $inProgress = Get-WindowsUpdateStates | Where-Object State -eq "Running" | Where-Object Title -notmatch "Microsoft Defender Antivirus"
    if ( $inProgress ) {
        $title = $inProgress.Title -join "`n"
        throw "Windows updates are still installing: $title"
    }
}

$filter = @{
    LogName      = "System"
    Id           = 19, 20, 43
    ProviderName = "Microsoft-Windows-WindowsUpdateClient"
}
Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue | Format-List TimeCreated, Id, Message
