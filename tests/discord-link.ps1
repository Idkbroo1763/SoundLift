$ErrorActionPreference='Stop'
$source = Get-Content "$PSScriptRoot/../SoundLift.ps1" -Raw
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-DiscordLinkOfflineGrace'},$true)
Invoke-Expression $function.Extent.Text
$script:installationId='test-install'; $script:discordLinkGraceHours=720
function Get-DiscordLinkCache { return $script:testCache }
foreach($case in @(
 @{age=1;id='test-install';expected=$true},
 @{age=719;id='test-install';expected=$true},
 @{age=721;id='test-install';expected=$false},
 @{age=-1;id='test-install';expected=$false},
 @{age=1;id='other-install';expected=$false}
)) {
 $script:testCache=@{linked=$true;installationId=$case.id;lastVerifiedUtc=[DateTime]::UtcNow.AddHours(-$case.age).ToString('o')}
 if ((Test-DiscordLinkOfflineGrace) -ne $case.expected) { throw "Offline grace case failed: $($case|Out-String)" }
}
$gate=$source.IndexOf('if (-not (Confirm-DiscordAccountLink))')
if($gate -lt 0 -or $gate -gt $source.IndexOf('$xaml =')) { throw 'Discord gate must precede UI creation' }
$buildSource = Get-Content "$PSScriptRoot/../build-windows.ps1" -Raw
foreach ($requiredUniversalBuildFragment in @(
 "licenseMode = 'universal'",
 "licenseProductId = 'soundlift-custom'",
 '/verify-license',
 'SOUNDLIFT_LOG_ANON_KEY'
)) {
 if (-not $buildSource.Contains($requiredUniversalBuildFragment)) { throw "Missing universal build behavior: $requiredUniversalBuildFragment" }
}
if (-not $buildSource.Contains('RELEASE_CONFIGURATION_EMBEDDING_VERIFIED')) { throw 'Missing release configuration verification' }
if (-not $source.Contains("`$script:appVersion = '2.0.1'")) { throw 'Application version was not updated to 2.0.1' }
foreach ($requiredV2DashboardFragment in @('SoundLift V2.0.1', 'GYORS PROFILOK', 'QuickProfileButton', 'DashboardCard', 'SOUNDLIFT PRO', 'ProfileManagerButton', "`$activeButton.Background = `$window.Resources['AccentGradient']")) {
 if (-not $source.Contains($requiredV2DashboardFragment)) { throw "Missing V2.0 dashboard behavior: $requiredV2DashboardFragment" }
}
foreach ($requiredFeature in @('Invoke-SoundLiftDownload','Repair-SoundLiftApoInclude','Show-ProblemReportWindow','Show-PostUpdateResult','Show-PrivacyWindow','Disable-SoundLiftEffects')) {
    if (-not $source.Contains("function $requiredFeature")) { throw "Missing required SoundLift feature: $requiredFeature" }
}
foreach ($requiredRepairAndOnboardingFeature in @(
    'function Get-SoundLiftApoHealth', 'SOUNDLIFT_CONFIG_INVALID', 'automatic_repair_result',
    'function Test-AndOfferSoundLiftRepair', 'Repair-SoundLiftApoInclude -Automatic',
    'function Open-SoundLiftDeviceSelector', 'Play-TestTone 60 1.5', 'Profile=$true',
    'function Open-SoundLiftDeviceSelector', 'Show-FirstRunWizard } else { Test-AndOfferSoundLiftRepair }'
)) {
    if (-not $source.Contains($requiredRepairAndOnboardingFeature)) { throw "Missing V1.6.0 repair or onboarding feature: $requiredRepairAndOnboardingFeature" }
}
foreach ($requiredStartupFix in @('function Start-AsyncAppUpdateCheck', 'DownloadStringAsync', 'if (Test-DiscordLinkOfflineGrace) { return $true }')) {
    if (-not $source.Contains($requiredStartupFix)) { throw "Missing responsive startup behavior: $requiredStartupFix" }
}
foreach ($requiredGameAndMicrophoneFix in @(
    '$overlay.ShowActivated=$false', '$overlay.Focusable=$false',
    '-not $window.IsActive',
    'ERole.eConsole, ERole.eMultimedia, ERole.eCommunications',
    'GetMasterVolumeLevelScalar(out confirmed)',
    'SetChannelVolumeLevelScalar(channel, target, ref context)',
    "`$isShadowMicrophone=`$microphoneName -match 'Shadow Virtual Audio'",
    'if($isShadowMicrophone){Show-SoundLiftMessage'
)) {
    if (-not $source.Contains($requiredGameAndMicrophoneFix)) { throw "Missing game focus or microphone volume fix: $requiredGameAndMicrophoneFix" }
}
foreach ($removedVisibleFeature in @(
    'Content="Automatikus profilváltás"', 'Content="Éjszakai mód"',
    'Content="Profilváltási jelzés"', 'Content="Discord-állapot megjelenítése"',
    'Content="▤  Statisztikák"', 'Content="⚙  Tulajdonosi tesztmód"',
    'Content="↶  Korábbi verzió visszaállítása"', "Content='Mikrofon teszt'",
    "Content='Zajszűrés kérése", "Content='Beszédkiegyenlítés"
)) {
    if ($source.Contains($removedVisibleFeature)) { throw "Obsolete visible feature is still present: $removedVisibleFeature" }
}
foreach ($requiredSimplifiedUi in @('Name="ProfileManagerButton"', "`$ProfileManagerButton.Add_Click", "`$windowsSoundItem = `$trayMenu.Items.Add", "Start-Process 'ms-settings:sound'")) {
    if (-not $source.Contains($requiredSimplifiedUi)) { throw "Missing simplified UI behavior: $requiredSimplifiedUi" }
}
foreach ($requiredModernUi in @(
    'function Get-SoundLiftThemePalette', 'function Set-SoundLiftWindowStyle',
    'function Set-SoundLiftElementTheme', 'function Show-SoundLiftMessage',
    'Get-SoundLiftSavedThemeName', "`$dialog.Resources['AccentGradient']",
    'TextWrapping=', 'PrimaryAction'
)) {
    if (-not $source.Contains($requiredModernUi)) { throw "Missing modern theme-aware UI behavior: $requiredModernUi" }
}
if ($source.Contains('[System.Windows.MessageBox]::Show')) { throw 'Legacy non-themed Windows message box is still present' }
foreach ($requiredWindowsStartupFix in @(
    'function Test-SoundLiftStartupTask', 'function Enable-SoundLiftStartupTask',
    'New-ScheduledTaskTrigger -AtLogOn', 'New-ScheduledTaskPrincipal', '-RunLevel Highest',
    'Register-ScheduledTask -TaskName $startupTaskName', 'Unregister-ScheduledTask -TaskName $startupTaskName'
)) {
    if (-not $source.Contains($requiredWindowsStartupFix)) { throw "Missing reliable Windows startup behavior: $requiredWindowsStartupFix" }
}
foreach ($requiredControlFeature in @(
 'function Invoke-QuickMute', 'function Register-SoundLiftHotKeys', 'function Show-HotkeyEditor',
 'Gyorsprofilok', 'DoNotDisturbCheck', 'ToolTip=',
 '$script:hotKeyBindings', 'Get-SoundLiftHotKeyText', 'Test-SoundLiftHotKeyBinding',
 'Add_PreviewKeyDown', 'RegisterHotKey($script:windowHandle', 'Select-Object -Unique'
)) {
    if (-not $source.Contains($requiredControlFeature)) { throw "Missing V1.3.15 quick-control feature: $requiredControlFeature" }
}
foreach ($requiredCustomHotkeyFeature in @(
 'version = 11',
 'modifiers=[int]$_.modifiers; key=[int]$_.key',
 "`$keyName -match '^D([0-9])`$'",
 'nativeModifiers = [uint32]([int]$binding.modifiers -bor 0x4000)',
 '$clear=[Windows.Controls.Button]::new()',
 '$activeSignatures|Select-Object -Unique',
 '($modifiers -band 3) -eq 3 -and $key -eq 0x2E',
 'if ([int]$binding.key -eq 0) { continue }'
)) {
    if (-not $source.Contains($requiredCustomHotkeyFeature)) { throw "Missing V1.3.20 custom hotkey behavior: $requiredCustomHotkeyFeature" }
}
foreach($requiredHotkeySaveFix in @('$cancel.Width=112; $cancel.Height=42','$save.Width=112; $save.Height=42','$save.IsDefault=$true','$save.Tag=[PSCustomObject]@{ Dialog=$dialog; Selectors=@($selectors) }','$save=$sender; $dialog=$sender.Tag.Dialog; $selectors=@($sender.Tag.Selectors)','$dialog.DialogResult=$true','$saveError=$_.Exception.Message')){
    if(-not $source.Contains($requiredHotkeySaveFix)){throw "Missing reliable hotkey save behavior: $requiredHotkeySaveFix"}
}
if ($source.Contains('Minden parancs Ctrl+Alt + a kiválasztott szám')) { throw 'Legacy number-only hotkey editor is still present' }
if ($source.Contains('Önmagában csak az F1–F24 funkcióbillentyűk használhatók.')) { throw 'Single-key shortcuts are still limited to function keys' }
foreach($requiredFreeKeyFeature in @('$singleKeys=@($bindings|Where-Object','modifiers -eq 0',"`$answer -ne 'Yes'")){
    if(-not $source.Contains($requiredFreeKeyFeature)){throw "Missing V1.3.22 unrestricted shortcut behavior: $requiredFreeKeyFeature"}
}
foreach ($requiredTrayMeterFeature in @(
    'GetDefaultOutputPeaks', 'IAudioMeterInformation', 'LeftPeakMeter', 'RightPeakMeter',
    'LiveBoostText', 'LiveClipText', '$volumeMenu.Text=', '$bypassItem.Add_Click',
    '$windowsSoundItem.Add_Click', 'audioMeterTimer'
)) {
    if (-not $source.Contains($requiredTrayMeterFeature)) { throw "Missing V1.3.24 tray or live meter behavior: $requiredTrayMeterFeature" }
}
foreach ($requiredProfileMixerFeature in @(
    'function Apply-ProfileLayout', 'function Show-ProfileOrderEditor', 'profileOrder = @(',
    'hiddenProfiles = @(', 'ProfileOrderButton', 'AppVolumeButton', 'ms-settings:apps-volume',
    "version = 11", "@('Music') +", 'list.Height=250', 'toggle.Height=40'
)) {
    if (-not $source.Contains($requiredProfileMixerFeature)) { throw "Missing V1.3.25 profile order or app volume behavior: $requiredProfileMixerFeature" }
}
foreach ($requiredTrayLifecycleFeature in @(
    'function Show-SoundLiftMainWindow', '$eventArgs.Cancel = $true', '$window.Hide()',
    '$script:trayIcon.Visible = $true', '$script:trayIcon.Add_DoubleClick',
    '$script:trayIcon.ContextMenuStrip = $trayMenu', '$window.Topmost = $true'
)) {
    if (-not $source.Contains($requiredTrayLifecycleFeature)) { throw "Missing V1.4.0 tray lifecycle behavior: $requiredTrayLifecycleFeature" }
}
$trayCreation=$source.IndexOf('$script:trayIcon = New-Object Windows.Forms.NotifyIcon')
$trayMenuCreation=$source.IndexOf('$trayMenu = New-Object Windows.Forms.ContextMenuStrip')
if($trayCreation -lt 0 -or $trayCreation -gt $trayMenuCreation){throw 'NotifyIcon is not created before tray menu initialization'}
if(([regex]::Matches($source,[regex]::Escape('$script:trayIcon.Dispose()'))).Count -ne 1){throw 'NotifyIcon must be disposed exactly once, by the real Exit action'}
if ([regex]::IsMatch($source, '(?m)^\$presenceTimer\.Start\(\)\s*$')) { throw 'Removed Discord presence timer must not start' }
if ([regex]::IsMatch($source, '(?m)^\$autoTimer\.Start\(\)\s*$')) { throw 'Removed automatic profile timer must not start' }
if ($source.Contains('Check-AppUpdate -Silent')) { throw 'Blocking startup update check is still enabled' }
$installerSource = Get-Content "$PSScriptRoot/../installer.iss" -Raw
$uninstallerSource = Get-Content "$PSScriptRoot/../Uninstall-SoundLift.ps1" -Raw
foreach ($requiredCleanupMarker in @('[UninstallRun]', 'Uninstall-SoundLift.ps1')) {
    if (-not $installerSource.Contains($requiredCleanupMarker)) { throw "Missing clean uninstall integration: $requiredCleanupMarker" }
}
foreach ($requiredCleanupBehavior in @('Remove-SoundLiftInclude', "Join-Path `$env:APPDATA 'SoundLift'", "Join-Path `$env:LOCALAPPDATA 'SoundLift'", "'SoundLift.lnk'", 'Unregister-ScheduledTask')) {
    if (-not $uninstallerSource.Contains($requiredCleanupBehavior)) { throw "Missing clean uninstall behavior: $requiredCleanupBehavior" }
}
if (-not $source.Contains("`$script:discordLinkGraceHours = 720")) { throw 'Offline grace period is not 30 days' }
foreach ($requiredThemeMarker in @('#C084FC','#22D3EE','#FB923C','#FACC55','OLED fekete','Midnight Blue','Purple Neon','Cyberpunk','Emerald','Carbon Gold')) {
    if (-not $source.Contains($requiredThemeMarker)) { throw "Missing SoundLift theme marker: $requiredThemeMarker" }
}
foreach ($requiredThemeStartupFix in @("if (`$entry.Key -eq 'IsLight') { continue }", 'foreach ($themeOptionName in $script:themeNames)', 'try { Set-AppTheme $script:themeName } catch')) {
    if (-not $source.Contains($requiredThemeStartupFix)) { throw "Missing V1.6.6 theme startup fix: $requiredThemeStartupFix" }
}
if ($source.Contains("'Cyberpunk', 'Emerald', 'Arctic', 'R6 Siege'")) { throw 'Removed Arctic and R6 Siege theme names are still present in the selectable theme list' }
if ($source.Contains('CustomThemeButton') -or $source.Contains('Show-SoundLiftCustomThemeEditor') -or $source.Contains('$script:customTheme')) { throw 'The removed custom theme implementation is still present' }
foreach ($requiredUiFix in @(
    '<ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Hidden"',
    'function Test-SoundLiftProblemReportService',
    'function Test-SoundLiftProblemReportQueued',
    'Test-Path $script:logQueueFile',
    '<Style x:Key="VerticalEqSlider" TargetType="Slider">',
    '$ApplyButton.Foreground = $window.Resources[''AccentContrastBrush'']'
)) {
    if (-not $source.Contains($requiredUiFix)) { throw "Missing V1.3.6 UI fix: $requiredUiFix" }
}
foreach ($requiredReportFix in @(
    '$response.discord_forwarded -ge [int]$response.accepted',
    '<TextBlock Text="{TemplateBinding Content}" Foreground="{DynamicResource PrimaryTextBrush}"',
    '<TextBlock Text="{TemplateBinding Content}" Foreground="{DynamicResource AccentContrastBrush}"',
    '<Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>'
)) {
    if (-not $source.Contains($requiredReportFix)) { throw "Missing V1.3.9 report/theme fix: $requiredReportFix" }
}
$logEventsSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\licensing\log-events\index.ts'))
foreach ($requiredBackendFix in @('manual_diagnostic_report','user_description','diagnostic_report','submitted_by_user','discord_forwarded: discordForwarded')) {
    if (-not $logEventsSource.Contains($requiredBackendFix)) { throw "Missing manual report backend support: $requiredBackendFix" }
}
$backendLoggerSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\licensing\_shared\backend-logger.ts'))
foreach ($requiredEncodingFix in @('function repairMojibake', 'new TextDecoder("utf-8", { fatal: true })')) {
    if (-not $backendLoggerSource.Contains($requiredEncodingFix)) { throw "Missing Discord encoding repair: $requiredEncodingFix" }
}
foreach ($requiredUpdaterFragment in @(
 'https://api.github.com/repos/Idkbroo1763/SoundLift/releases/latest',
 "`$_.name -in @('SoundLift.Setup.exe', 'SoundLift Setup.exe')",
 "SoundLift[ .]Setup\.exe",
 "[Text.UTF8Encoding]::new(`$false).GetBytes(`$body)",
 "Get-FileHash -LiteralPath `$installerPath -Algorithm SHA256",
 "`$assetUri.Scheme -ne 'https' -or `$assetUri.Host -ne 'github.com'",
 "`$helperPath = Join-Path `$temporaryDirectory 'install-update.ps1'",
 'Wait-Process -Id',
 "'/VERYSILENT'",
 '-Wait -PassThru',
 'Start-Process -FilePath `$applicationPath',
 "`$statusText.Text = 'Let",
 "`$statusText.Text = 'Telep",
 "`$installButton.Content = '",
 'CopySupportIdButton',
 'LicenseStatusText',
 'LicenseButton',
 "`$script:licenseMode -notin @('universal','custom')",
 'RollbackButton',
 "`$script:currentLicenseType -ne 'developer'",
 "`$RollbackButton.Visibility = 'Collapsed'"
)) {
 if (-not $source.Contains($requiredUpdaterFragment)) { throw "Missing secure updater behavior: $requiredUpdaterFragment" }
}
foreach ($name in @('Get-SoundLiftRollbackState', 'Save-SoundLiftRollbackCopy')) {
 $definition = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}, $true)
 Invoke-Expression $definition.Extent.Text
}
$script:appDirectory = Join-Path ([IO.Path]::GetTempPath()) ('soundlift-rollback-' + [Guid]::NewGuid())
[IO.Directory]::CreateDirectory($script:appDirectory) | Out-Null
$script:appLaunchPath = Join-Path $script:appDirectory 'SoundLift.exe'; $script:isPackagedExe=$true; $script:appVersion='1.2.1'; $script:currentLicenseType='free'
try {
 [IO.File]::WriteAllBytes($script:appLaunchPath, [byte[]](1,2,3,4,5))
 Save-SoundLiftRollbackCopy
 if (Test-Path (Join-Path $script:appDirectory 'rollback\SoundLift.previous.exe')) { throw 'Free user received a rollback executable' }
 $script:currentLicenseType='developer'
 Save-SoundLiftRollbackCopy
 $script:appVersion='2.0.1'
 if (-not (Get-SoundLiftRollbackState)) { throw 'Valid rollback copy was rejected' }
 [IO.File]::AppendAllText((Join-Path $script:appDirectory 'rollback\SoundLift.previous.exe'), 'tampered')
 if (Get-SoundLiftRollbackState) { throw 'Tampered rollback copy was accepted' }
 Write-Host 'PASS: rollback backup is created and hash tampering is rejected'
} finally { Remove-Item -LiteralPath $script:appDirectory -Recurse -Force }
Write-Host 'PASS: PowerShell syntax, expiry, future-clock rejection, installation binding, early gate'

# Exercise the application's assembly loading and real DPAPI persistence in a
# fresh Windows PowerShell process, before any other code can load System.Security.
Invoke-Expression $source.Substring(0, $source.IndexOf('# PS2EXE'))
foreach ($name in @('Protect-LicenseState', 'Unprotect-LicenseState', 'Get-InstallationProof')) {
 $definition = $ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}, $true)
 Invoke-Expression $definition.Extent.Text
}
$script:logRoot = Join-Path ([IO.Path]::GetTempPath()) ('soundlift-dpapi-' + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $script:logRoot | Out-Null
try {
 $proof = Get-InstallationProof
 if ($proof -notmatch '^[a-f0-9]{64}$') { throw 'Invalid generated proof' }
 if ((Get-InstallationProof) -cne $proof) { throw 'Proof did not survive disk round trip' }
 $stored = [IO.File]::ReadAllText((Join-Path $script:logRoot 'installation-proof.dat'))
 if ($stored.Contains($proof)) { throw 'Proof stored without encryption' }
 $state = Unprotect-LicenseState (Protect-LicenseState @{linked=$true;supportId='SL-TEST'})
 if ($state.linked -ne $true -or $state.supportId -ne 'SL-TEST') { throw 'Link cache round trip failed' }
 Write-Host 'PASS: explicit assembly loading, real DPAPI encryption, persistent proof and cache'
} finally { Remove-Item -LiteralPath $script:logRoot -Recurse -Force }
