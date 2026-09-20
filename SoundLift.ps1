# Windows PowerShell / PS2EXE does not automatically load the DPAPI assembly.
$requiredAssemblies = @(
    'System.Security',
    'WindowsBase',
    'PresentationCore',
    'PresentationFramework',
    'System.Xaml',
    'System.Windows.Forms',
    'System.Drawing'
)
foreach ($assemblyName in $requiredAssemblies) {
    $null = [Reflection.Assembly]::LoadWithPartialName($assemblyName)
}

# PS2EXE alatt a $PSScriptRoot üres lehet. Ilyenkor az EXE saját mappáját
# használjuk minden alkalmazáshoz tartozó fájl és parancsikon alapjaként.
$script:isPackagedExe = [string]::IsNullOrWhiteSpace($PSScriptRoot)
$script:appDirectory = if ($script:isPackagedExe) {
    [AppDomain]::CurrentDomain.BaseDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar)
} else {
    $PSScriptRoot
}
$script:appLaunchPath = if ($script:isPackagedExe) {
    [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
} else {
    Join-Path $script:appDirectory 'SoundLift.bat'
}
$script:appVersion = '1.6.0'
$script:hotKeyVirtualKeys = @(0x31,0x32,0x33,0x34,0x35,0x36,0x30)
$script:hotKeyBindings = @($script:hotKeyVirtualKeys | ForEach-Object { [PSCustomObject]@{ modifiers=3; key=[int]$_ } })
$script:doNotDisturb = $false
$script:isQuickMuted = $false
$script:preMuteVolume = 100
$script:isBypassed = $false
$script:profileOrder = @('Music','FiveM RP','FiveM Combat','R6','Discord','Movie','Heavy','Custom')
$script:hiddenProfiles = @()
$script:onboardingCompleted = $false
$script:discordApplicationId = '1547231878577393716'
$script:discordPresencePipe = $null
$script:lastDiscordPresenceSignature = ''
$script:sessionStartedUtc = [DateTime]::UtcNow
$script:statistics = $null
$script:lastClipStatisticUtc = [DateTime]::MinValue
$script:profileOverlayEnabled = $false
$script:nightModeEnabled = $false
# A kiadott alkalmazás univerzális: ingyenes módban indul, és ugyanabban az
# EXE-ben aktiválható customer vagy developer licenc.
$script:licenseMode = 'universal'
$script:currentLicenseType = 'free'
$script:currentLicenseStatus = 'inactive'
$script:currentLicenseVariant = 'ingyenes'
$script:currentLicenseActivatedUtc = ''
$script:currentLicenseDeviceRef = ''
$script:isOwner = $false
$script:licenseFeatures = @{}
$script:simulatedLicenseLabel = ''
$script:licenseApiUrl = 'https://uvilqzgbgirdoryavaqp.supabase.co/functions/v1/verify-license'
$script:licenseProductId = 'soundlift-custom'
$script:licenseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2aWxxemdiZ2lyZG9yeWF2YXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4OTY1MzUsImV4cCI6MjEwNDQ3MjUzNX0.6qFhCs5onFuH1uOvlk8C6V4P_fOnNRPxzWXmfdnvCcc'
# A build-szkriptek kizárólag a publikus naplófogadó végpontot és a Supabase
# anon kulcsot építhetik be. Discord webhook, bot token és service-role kulcs
# soha nem kerülhet a kliensbe.
$script:logApiUrl = 'https://uvilqzgbgirdoryavaqp.supabase.co/functions/v1/log-events'
$script:logAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2aWxxemdiZ2lyZG9yeWF2YXFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4OTY1MzUsImV4cCI6MjEwNDQ3MjUzNX0.6qFhCs5onFuH1uOvlk8C6V4P_fOnNRPxzWXmfdnvCcc'
$script:discordLinkRequired = $true
$script:discordLinkGraceHours = 720
$script:loggerInitialized = $false
$script:startupCompleted = $false
$script:themeName = 'Fekete és piros'

function Get-SoundLiftThemePalette([string]$themeName = $script:themeName) {
    $theme = switch ($themeName) {
        { $_ -in @('Fekete és kék','Black & Blue') }     { @{ Accent='#38BDF8'; AccentDark='#0369A1'; Page='#071824'; Hover='#12364A' } }
        { $_ -in @('Grafit és zöld','Graphite & Green') } { @{ Accent='#4ADE80'; AccentDark='#15803D'; Page='#092016'; Hover='#143A26' } }
        'Fekete és lila'    { @{ Accent='#C084FC'; AccentDark='#7E22CE'; Page='#1A0B28'; Hover='#382050' } }
        'Éjkék és türkiz'   { @{ Accent='#22D3EE'; AccentDark='#0E7490'; Page='#061E2D'; Hover='#123C4C' } }
        'Grafit és narancs' { @{ Accent='#FB923C'; AccentDark='#C2410C'; Page='#241307'; Hover='#422414'; Contrast='#111113' } }
        'Fekete és arany'   { @{ Accent='#FACC55'; AccentDark='#A16207'; Page='#211804'; Hover='#3B2D10'; Contrast='#111113' } }
        'OLED fekete'       { @{ Accent='#F8FAFC'; AccentDark='#64748B'; Page='#000000'; Hover='#202024'; Base='#000000'; Surface='#070709'; SurfaceAlt='#000000'; Control='#111114'; Border='#303038'; Contrast='#09090B' } }
        default             { @{ Accent='#FF4D67'; AccentDark='#A60024'; Page='#220A10'; Hover='#40131C' } }
    }
    return @{
        Accent=$theme.Accent; AccentDark=$theme.AccentDark; Page=$theme.Page; Hover=$theme.Hover
        Base=$(if($theme.Base){$theme.Base}else{'#070709'}); Surface=$(if($theme.Surface){$theme.Surface}else{'#121216'})
        SurfaceAlt=$(if($theme.SurfaceAlt){$theme.SurfaceAlt}else{'#0C0C10'}); Control=$(if($theme.Control){$theme.Control}else{'#1A1A20'})
        Border=$(if($theme.Border){$theme.Border}else{'#303038'}); Primary=$(if($theme.Primary){$theme.Primary}else{'#F8FAFC'})
        Secondary=$(if($theme.Secondary){$theme.Secondary}else{'#D4D9E2'}); Muted=$(if($theme.Muted){$theme.Muted}else{'#8B96A8'})
        Section=$(if($theme.Section){$theme.Section}else{'#AEB7C6'}); Contrast=$(if($theme.Contrast){$theme.Contrast}else{'#FFFFFF'})
        Success='#4ADE80'; Warning='#FBBF24'; Danger='#FB7185'
    }
}

function Get-SoundLiftSavedThemeName {
    try {
        $earlySettingsPath = Join-Path $env:APPDATA 'SoundLift\settings.json'
        if (Test-Path -LiteralPath $earlySettingsPath) {
            $saved = Get-Content -LiteralPath $earlySettingsPath -Raw | ConvertFrom-Json
            $name = [string]$saved.theme
            $normalized = switch ($name) { 'Black & Red' {'Fekete és piros'} 'Black & Blue' {'Fekete és kék'} 'Graphite & Green' {'Grafit és zöld'} 'Világos' {'Fekete és piros'} default { if($name){$name}else{'Fekete és piros'} } }
            return $normalized
        }
    } catch { }
    return 'Fekete és piros'
}
$script:themeName = Get-SoundLiftSavedThemeName

function New-SoundLiftBrush([string]$color) {
    return [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($color))
}

function Set-SoundLiftElementTheme([Windows.DependencyObject]$element, [hashtable]$palette) {
    if ($null -eq $element) { return }
    if ($element -is [Windows.Controls.TextBlock]) {
        $element.Foreground = if ($element.FontSize -ge 20) { New-SoundLiftBrush $palette.Accent } elseif ($element.FontSize -le 12) { New-SoundLiftBrush $palette.Muted } else { New-SoundLiftBrush $palette.Primary }
        $element.TextWrapping = if ($element.TextWrapping -eq 'NoWrap') { 'NoWrap' } else { 'Wrap' }
    } elseif ($element -is [Windows.Controls.Button]) {
        if (-not $element.Style) {
            $element.Background = New-SoundLiftBrush $(if([string]$element.Tag -eq 'PrimaryAction'){$palette.Accent}else{$palette.Control})
            $element.Foreground = New-SoundLiftBrush $(if([string]$element.Tag -eq 'PrimaryAction'){$palette.Contrast}else{$palette.Primary})
            $element.BorderBrush = New-SoundLiftBrush $palette.Border; $element.BorderThickness = [Windows.Thickness]::new(1)
            $element.Padding = [Windows.Thickness]::new(16,9,16,9); $element.MinHeight = [Math]::Max(38, $element.MinHeight)
        }
        $element.FontFamily = 'Segoe UI Semibold'; $element.Cursor = 'Hand'
    } elseif ($element -is [Windows.Controls.TextBox] -or $element -is [Windows.Controls.ComboBox] -or $element -is [Windows.Controls.ListBox]) {
        $element.Background = New-SoundLiftBrush $palette.Control; $element.Foreground = New-SoundLiftBrush $palette.Primary
        $element.BorderBrush = New-SoundLiftBrush $palette.Border; $element.BorderThickness = [Windows.Thickness]::new(1)
    } elseif ($element -is [Windows.Controls.CheckBox] -or $element -is [Windows.Controls.RadioButton]) {
        $element.Foreground = New-SoundLiftBrush $palette.Secondary
    } elseif ($element -is [Windows.Controls.Border]) {
        if ($element.Background -and $element.Background -is [Windows.Media.SolidColorBrush] -and $element.Background.Color.ToString() -in @('#FF09090B','#FF0B0B0D','#FF111113','#FF08090B','#FF050505')) { $element.Background = New-SoundLiftBrush $palette.Surface }
        if ($element.BorderThickness.Left -gt 0) { $element.BorderBrush = New-SoundLiftBrush $palette.Border }
    }
    $count = [Windows.Media.VisualTreeHelper]::GetChildrenCount($element)
    for ($i = 0; $i -lt $count; $i++) { Set-SoundLiftElementTheme ([Windows.Media.VisualTreeHelper]::GetChild($element,$i)) $palette }
}

function Set-SoundLiftWindowStyle([Windows.Window]$targetWindow) {
    if ($null -eq $targetWindow) { return }
    $palette = Get-SoundLiftThemePalette
    $accent = [Windows.Media.ColorConverter]::ConvertFromString($palette.Accent)
    $accentDark = [Windows.Media.ColorConverter]::ConvertFromString($palette.AccentDark)
    $base = [Windows.Media.ColorConverter]::ConvertFromString($palette.Base)
    $page = [Windows.Media.ColorConverter]::ConvertFromString($palette.Page)
    $gradient = [Windows.Media.LinearGradientBrush]::new(); $gradient.StartPoint=[Windows.Point]::new(0,0); $gradient.EndPoint=[Windows.Point]::new(1,1)
    $gradient.GradientStops.Add([Windows.Media.GradientStop]::new($base,0)); $gradient.GradientStops.Add([Windows.Media.GradientStop]::new($page,0.55)); $gradient.GradientStops.Add([Windows.Media.GradientStop]::new($base,1))
    $accentGradient = [Windows.Media.LinearGradientBrush]::new(); $accentGradient.StartPoint=[Windows.Point]::new(0,0); $accentGradient.EndPoint=[Windows.Point]::new(1,1)
    $accentGradient.GradientStops.Add([Windows.Media.GradientStop]::new($accent,0)); $accentGradient.GradientStops.Add([Windows.Media.GradientStop]::new($accentDark,1))
    $targetWindow.Background=$gradient; $targetWindow.Foreground=New-SoundLiftBrush $palette.Primary; $targetWindow.FontFamily='Segoe UI'
    $targetWindow.Resources['PageGradient']=$gradient; $targetWindow.Resources['AccentGradient']=$accentGradient
    foreach($entry in @{AccentText=$palette.Accent;Hover=$palette.Hover;Surface=$palette.Surface;SurfaceAlt=$palette.SurfaceAlt;Control=$palette.Control;Border=$palette.Border;PrimaryText=$palette.Primary;SecondaryText=$palette.Secondary;MutedText=$palette.Muted;SectionText=$palette.Section;AccentContrast=$palette.Contrast}.GetEnumerator()) { $targetWindow.Resources[($entry.Key+'Brush')] = New-SoundLiftBrush ([string]$entry.Value) }
    if ($targetWindow.Owner) { $targetWindow.WindowStartupLocation='CenterOwner' }
    if ($targetWindow.Width -gt 0) { $targetWindow.MinWidth=[Math]::Min($targetWindow.Width,420) }
    if ($targetWindow.Height -gt 0) { $targetWindow.MinHeight=[Math]::Min($targetWindow.Height,220) }
    $targetWindow.MaxHeight=[Windows.SystemParameters]::WorkArea.Height-32; $targetWindow.MaxWidth=[Windows.SystemParameters]::WorkArea.Width-32
    $themeIconPath=Join-Path $script:appDirectory 'SoundLift.ico';if(Test-Path -LiteralPath $themeIconPath){try{$targetWindow.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([Uri]$themeIconPath)}catch{}}
    $targetWindow.Add_SourceInitialized({try{$handle=[Windows.Interop.WindowInteropHelper]::new($targetWindow).Handle;$dark=1;[void][AudioAppNative]::DwmSetWindowAttribute($handle,20,[ref]$dark,4)}catch{}}.GetNewClosure())
    $targetWindow.Add_ContentRendered({ Set-SoundLiftElementTheme $targetWindow.Content (Get-SoundLiftThemePalette) }.GetNewClosure())
}

function Show-SoundLiftMessage {
    param([string]$Message,[string]$Title='SoundLift',[ValidateSet('OK','YesNo')][string]$Buttons='OK',[ValidateSet('Information','Warning','Error','Question')][string]$Icon='Information',[Windows.Window]$Owner=$null)
    $palette=Get-SoundLiftThemePalette; $dialog=[Windows.Window]::new(); $dialog.Title=$Title; $dialog.Width=560; $dialog.Height=[Math]::Min(460,[Math]::Max(250,210+([Math]::Ceiling($Message.Length/58)*22)))
    $dialog.ResizeMode='NoResize'; $dialog.ShowInTaskbar=$false; if($Owner){$dialog.Owner=$Owner}; Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.Grid]::new(); $root.Margin=[Windows.Thickness]::new(26); $root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new()); $buttonRow=[Windows.Controls.RowDefinition]::new();$buttonRow.Height=[Windows.GridLength]::Auto;$root.RowDefinitions.Add($buttonRow)
    $card=[Windows.Controls.Border]::new();$card.Background=New-SoundLiftBrush $palette.Surface;$card.BorderBrush=New-SoundLiftBrush $palette.Border;$card.BorderThickness=[Windows.Thickness]::new(1);$card.CornerRadius=[Windows.CornerRadius]::new(16);$card.Padding=[Windows.Thickness]::new(20)
    $body=[Windows.Controls.StackPanel]::new();$heading=[Windows.Controls.TextBlock]::new();$heading.Text=switch($Icon){'Error'{'Hiba'}'Warning'{'Figyelmeztetés'}'Question'{'Megerősítés'}default{'Információ'}};$heading.FontSize=12;$heading.FontWeight='Bold';$heading.Foreground=New-SoundLiftBrush $(switch($Icon){'Error'{$palette.Danger}'Warning'{$palette.Warning}default{$palette.Accent}})
    $text=[Windows.Controls.TextBlock]::new();$text.Text=$Message;$text.TextWrapping='Wrap';$text.FontSize=14;$text.LineHeight=22;$text.Foreground=New-SoundLiftBrush $palette.Primary;$text.Margin=[Windows.Thickness]::new(0,10,0,0);[void]$body.Children.Add($heading);[void]$body.Children.Add($text);$card.Child=$body;$scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto';$scroll.HorizontalScrollBarVisibility='Disabled';$scroll.Content=$card;[void]$root.Children.Add($scroll)
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.HorizontalAlignment='Right';$actions.Margin=[Windows.Thickness]::new(0,18,0,0);[Windows.Controls.Grid]::SetRow($actions,1)
    $dialog.Tag=[Windows.MessageBoxResult]::None
    if($Buttons -eq 'YesNo'){$no=[Windows.Controls.Button]::new();$no.Content='Nem';$no.Width=110;$no.Margin=[Windows.Thickness]::new(0,0,10,0);$no.Add_Click({$dialog.Tag=[Windows.MessageBoxResult]::No;$dialog.DialogResult=$false}.GetNewClosure());[void]$actions.Children.Add($no);$yes=[Windows.Controls.Button]::new();$yes.Content='Igen';$yes.Width=120;$yes.Tag='PrimaryAction';$yes.Background=$dialog.Resources['AccentGradient'];$yes.Foreground=$dialog.Resources['AccentContrastBrush'];$yes.Add_Click({$dialog.Tag=[Windows.MessageBoxResult]::Yes;$dialog.DialogResult=$true}.GetNewClosure());[void]$actions.Children.Add($yes)}else{$ok=[Windows.Controls.Button]::new();$ok.Content='Rendben';$ok.Width=120;$ok.Tag='PrimaryAction';$ok.Background=$dialog.Resources['AccentGradient'];$ok.Foreground=$dialog.Resources['AccentContrastBrush'];$ok.IsDefault=$true;$ok.Add_Click({$dialog.Tag=[Windows.MessageBoxResult]::OK;$dialog.DialogResult=$true}.GetNewClosure());[void]$actions.Children.Add($ok)}
    [void]$root.Children.Add($actions);$dialog.Content=$root;[void]$dialog.ShowDialog();return [Windows.MessageBoxResult]$dialog.Tag
}

function ConvertTo-SoundLiftSafeText([object]$value, [int]$maxLength = 1000) {
    if ($null -eq $value) { return '' }
    $text = [string]$value
    foreach ($path in @($env:USERPROFILE, $env:APPDATA, $env:LOCALAPPDATA)) {
        if (-not [string]::IsNullOrWhiteSpace($path)) { $text = $text.Replace($path, '%USERPROFILE%') }
    }
    $text = [Regex]::Replace($text, '(?i)\b(?:SL-[A-Z0-9-]{12,}|[A-F0-9]{32,})\b', '[REDACTED]')
    if ($text.Length -gt $maxLength) { return $text.Substring(0, $maxLength) }
    return $text
}

function Initialize-SoundLiftLogger {
    if ($script:loggerInitialized) { return }
    try {
        $script:logRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SoundLift\logs'
        if (-not (Test-Path $script:logRoot)) { [void][IO.Directory]::CreateDirectory($script:logRoot) }
        $script:logFile = Join-Path $script:logRoot ("soundlift-{0}.ndjson" -f (Get-Date -Format 'yyyy-MM-dd'))
        $script:logQueueFile = Join-Path $script:logRoot 'pending-events.ndjson'
        $script:logStateFile = Join-Path $script:logRoot 'logger-state.json'
        $installIdPath = Join-Path $script:logRoot 'installation-id.txt'
        if (Test-Path $installIdPath) { $script:installationId = ([IO.File]::ReadAllText($installIdPath)).Trim() }
        if ([string]::IsNullOrWhiteSpace($script:installationId) -or $script:installationId -notmatch '^[a-f0-9-]{36}$') {
            $script:installationId = [Guid]::NewGuid().ToString()
            [IO.File]::WriteAllText($installIdPath, $script:installationId, [Text.Encoding]::UTF8)
        }
        Get-ChildItem -LiteralPath $script:logRoot -Filter 'soundlift-*.ndjson' -File -ErrorAction SilentlyContinue |
            Where-Object LastWriteTimeUtc -lt ([DateTime]::UtcNow.AddDays(-14)) | Remove-Item -Force -ErrorAction SilentlyContinue
        $script:loggerInitialized = $true
    } catch { $script:loggerInitialized = $false }
}

function Get-SoundLiftSupportId {
    Initialize-SoundLiftLogger
    if ([string]::IsNullOrWhiteSpace($script:installationId)) { return 'SL-ISMERETLEN' }
    return 'SL-' + $script:installationId.Replace('-', '').Substring(0, 8).ToUpperInvariant()
}

function Add-SoundLiftPendingEvent([object]$event) {
    if (-not $script:loggerInitialized -or [string]::IsNullOrWhiteSpace($script:logApiUrl)) { return }
    try {
        $line = $event | ConvertTo-Json -Compress -Depth 6
        [IO.File]::AppendAllText($script:logQueueFile, $line + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        if ((Get-Item -LiteralPath $script:logQueueFile).Length -gt 1048576) {
            $tail = @(Get-Content -LiteralPath $script:logQueueFile -Tail 500 -ErrorAction Stop)
            [IO.File]::WriteAllLines($script:logQueueFile, $tail, [Text.UTF8Encoding]::new($false))
        }
    } catch { }
}

function Write-SoundLiftLog {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('startup','crash','update','license','security','developer_access')][string]$Category,
        [Parameter(Mandatory=$true)][string]$EventName,
        [ValidateSet('debug','info','warning','error','critical')][string]$Severity = 'info',
        [hashtable]$Data = @{},
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    try {
        Initialize-SoundLiftLogger
        if (-not $script:loggerInitialized) { return }
        $safeData = [ordered]@{}
        foreach ($key in @($Data.Keys)) {
            $limit = if ([string]$key -eq 'diagnostic_report') { 5000 } else { 1000 }
            $safeData[[string]$key] = ConvertTo-SoundLiftSafeText $Data[$key] $limit
        }
        if ($ErrorRecord) {
            $safeData.exception_type = ConvertTo-SoundLiftSafeText $ErrorRecord.Exception.GetType().FullName 200
            $safeData.message = ConvertTo-SoundLiftSafeText $ErrorRecord.Exception.Message 1000
            $safeData.script_stack = ConvertTo-SoundLiftSafeText $ErrorRecord.ScriptStackTrace 1600
        }
        $event = [ordered]@{
            schema_version = 1; event_id = [Guid]::NewGuid().ToString(); timestamp_utc = [DateTime]::UtcNow.ToString('o')
            category = $Category; event_name = (ConvertTo-SoundLiftSafeText $EventName 80); severity = $Severity
            app_version = $script:appVersion; installation_id = $script:installationId
            license_mode = $script:licenseMode; product_id = (ConvertTo-SoundLiftSafeText $script:licenseProductId 64); data = $safeData
        }
        [IO.File]::AppendAllText($script:logFile, (($event | ConvertTo-Json -Compress -Depth 6) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
        Add-SoundLiftPendingEvent $event
    } catch { }
}

function Send-SoundLiftPendingLogs {
    Initialize-SoundLiftLogger
    if (-not $script:loggerInitialized -or [string]::IsNullOrWhiteSpace($script:logApiUrl)) { return $false }
    if (-not (Test-Path $script:logQueueFile)) { return $true }
    try {
        $allLines = @(Get-Content -LiteralPath $script:logQueueFile -ErrorAction Stop | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($allLines.Count -eq 0) { return $true }
        $take = [Math]::Min(50, $allLines.Count)
        $events = New-Object Collections.Generic.List[object]
        for ($i = 0; $i -lt $take; $i++) { try { $events.Add(($allLines[$i] | ConvertFrom-Json -ErrorAction Stop)) } catch { } }
        if ($events.Count -eq 0) { [IO.File]::Delete($script:logQueueFile); return $true }
        $headers = @{ 'User-Agent'="SoundLift/$($script:appVersion)" }
        if (-not [string]::IsNullOrWhiteSpace($script:logAnonKey)) { $headers.apikey=$script:logAnonKey; $headers.Authorization="Bearer $($script:logAnonKey)" }
        # Windows PowerShell 5.1 a Generic.List egyetlen elemes tartalmat
        # bizonyos esetekben objektumkent (nem JSON tombkent) szerializal.
        # A backend mindig {"events":[...]} formatumot var, ezert a tombot
        # explicit JSON-kent epitjuk fel egy- es tobbesemenyes kuldesnel is.
        $eventJson = @($events | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 8 })
        $headers['x-soundlift-installation-proof'] = Get-InstallationProof
        $body = '{"events":[' + ($eventJson -join ',') + ']}'
        # Windows PowerShell 5.1 otherwise sends string bodies using its legacy
        # default encoding, which corrupts Hungarian accents in Discord logs.
        $bodyBytes = [Text.UTF8Encoding]::new($false).GetBytes($body)
        $response = Invoke-RestMethod -Uri $script:logApiUrl -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $bodyBytes -TimeoutSec 8
        if ([int]$response.accepted -gt 0 -and [int]$response.discord_forwarded -ge [int]$response.accepted) {
            $remaining = if ($allLines.Count -gt $take) { @($allLines[$take..($allLines.Count - 1)]) } else { @() }
            [IO.File]::WriteAllLines($script:logQueueFile, $remaining, [Text.UTF8Encoding]::new($false))
            return $true
        }
        return $false
    } catch { return $false }
}

function Complete-SoundLiftStartup {
    try {
        $previousVersion = ''
        if (Test-Path $script:logStateFile) {
            try { $previousVersion = [string]((Get-Content -LiteralPath $script:logStateFile -Raw | ConvertFrom-Json).lastSuccessfulVersion) } catch { }
        }
        if ($previousVersion -and $previousVersion -ne $script:appVersion) {
            Write-SoundLiftLog -Category update -EventName 'version_changed' -Data @{ old_version=$previousVersion; new_version=$script:appVersion }
        }
        [IO.File]::WriteAllText($script:logStateFile, (@{lastSuccessfulVersion=$script:appVersion; updatedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json -Compress), [Text.Encoding]::UTF8)
        $script:startupCompleted = $true
        Write-SoundLiftLog -Category startup -EventName 'initialization_succeeded' -Data @{ packaged=$script:isPackagedExe }
    } catch { }
}

Initialize-SoundLiftLogger
Write-SoundLiftLog -Category startup -EventName 'process_started' -Data @{ packaged=$script:isPackagedExe }
trap {
    $crashEvent = if ($script:startupCompleted) { 'unhandled_runtime_error' } else { 'startup_crash' }
    Write-SoundLiftLog -Category crash -EventName $crashEvent -Severity critical -ErrorRecord $_
    if (-not $script:startupCompleted) { Write-SoundLiftLog -Category startup -EventName 'initialization_failed' -Severity critical -ErrorRecord $_ }
    [void](Send-SoundLiftPendingLogs)
    break
}
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class AudioAppNative {
    [DllImport("user32.dll", SetLastError=true)] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hWnd, int attribute, ref int value, int size);

    enum EDataFlow { eRender, eCapture, eAll }
    enum ERole { eConsole, eMultimedia, eCommunications }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    class MMDeviceEnumeratorComObject { }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    interface IMMDeviceEnumerator {
        int EnumAudioEndpoints(EDataFlow dataFlow, uint stateMask, out IntPtr devices);
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice endpoint);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    interface IMMDevice {
        int Activate(ref Guid iid, uint context, IntPtr activationParams, out IntPtr instance);
        int OpenPropertyStore(uint access, out IPropertyStore properties);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064")]
    interface IAudioMeterInformation {
        int GetPeakValue(out float peak);
        int GetMeteringChannelCount(out int channelCount);
        int GetChannelsPeakValues(int channelCount, [Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex=0)] float[] peakValues);
        int QueryHardwareSupport(out int hardwareSupportMask);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
    interface IAudioEndpointVolume {
        int RegisterControlChangeNotify(IntPtr notify);
        int UnregisterControlChangeNotify(IntPtr notify);
        int GetChannelCount(out uint channelCount);
        int SetMasterVolumeLevel(float levelDb, ref Guid eventContext);
        int SetMasterVolumeLevelScalar(float level, ref Guid eventContext);
        int GetMasterVolumeLevel(out float levelDb);
        int GetMasterVolumeLevelScalar(out float level);
        int SetChannelVolumeLevel(uint channel, float levelDb, ref Guid eventContext);
        int SetChannelVolumeLevelScalar(uint channel, float level, ref Guid eventContext);
        int GetChannelVolumeLevel(uint channel, out float levelDb);
        int GetChannelVolumeLevelScalar(uint channel, out float level);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid eventContext);
        int GetMute(out bool mute);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    interface IPropertyStore {
        int GetCount(out uint count);
        int GetAt(uint index, out PROPERTYKEY key);
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT value);
    }

    [StructLayout(LayoutKind.Sequential)] struct PROPERTYKEY { public Guid fmtid; public uint pid; }
    [StructLayout(LayoutKind.Explicit)] struct PROPVARIANT {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(8)] public IntPtr pointerValue;
    }

    public static string GetDefaultOutputName() {
        IMMDeviceEnumerator enumerator = null; IMMDevice device = null; IPropertyStore store = null;
        try {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device) != 0) return "Ismeretlen";
            if (device.OpenPropertyStore(0, out store) != 0) return "Ismeretlen";
            var key = new PROPERTYKEY { fmtid = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), pid = 14 };
            PROPVARIANT value;
            if (store.GetValue(ref key, out value) != 0 || value.pointerValue == IntPtr.Zero) return "Ismeretlen";
            return Marshal.PtrToStringUni(value.pointerValue) ?? "Ismeretlen";
        } catch { return "Ismeretlen"; }
        finally {
            if (store != null) Marshal.ReleaseComObject(store);
            if (device != null) Marshal.ReleaseComObject(device);
            if (enumerator != null) Marshal.ReleaseComObject(enumerator);
        }
    }

    public static float[] GetDefaultOutputPeaks() {
        IMMDeviceEnumerator enumerator = null; IMMDevice device = null; IAudioMeterInformation meter = null;
        try {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device) != 0) return new float[] { 0, 0 };
            Guid iid = typeof(IAudioMeterInformation).GUID;
            IntPtr instance;
            if (device.Activate(ref iid, 23, IntPtr.Zero, out instance) != 0 || instance == IntPtr.Zero) return new float[] { 0, 0 };
            meter = (IAudioMeterInformation)Marshal.GetObjectForIUnknown(instance);
            Marshal.Release(instance);
            int count;
            if (meter.GetMeteringChannelCount(out count) != 0 || count < 1) return new float[] { 0, 0 };
            float[] values = new float[count];
            if (meter.GetChannelsPeakValues(count, values) != 0) return new float[] { 0, 0 };
            float left = Math.Max(0, Math.Min(1, values[0]));
            float right = Math.Max(0, Math.Min(1, values.Length > 1 ? values[1] : values[0]));
            return new float[] { left, right };
        } catch { return new float[] { 0, 0 }; }
        finally {
            if (meter != null) Marshal.ReleaseComObject(meter);
            if (device != null) Marshal.ReleaseComObject(device);
            if (enumerator != null) Marshal.ReleaseComObject(enumerator);
        }
    }

    public static string GetDefaultInputName() {
        IMMDeviceEnumerator enumerator = null; IMMDevice device = null; IPropertyStore store = null;
        try {
            enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
            if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eCapture, ERole.eConsole, out device) != 0) return "Ismeretlen mikrofon";
            if (device.OpenPropertyStore(0, out store) != 0) return "Ismeretlen mikrofon";
            var key = new PROPERTYKEY { fmtid = new Guid("A45C254E-DF1C-4EFD-8020-67D146A850E0"), pid = 14 };
            PROPVARIANT value;
            if (store.GetValue(ref key, out value) != 0 || value.pointerValue == IntPtr.Zero) return "Ismeretlen mikrofon";
            return Marshal.PtrToStringUni(value.pointerValue) ?? "Ismeretlen mikrofon";
        } catch { return "Ismeretlen mikrofon"; }
        finally {
            if (store != null) Marshal.ReleaseComObject(store);
            if (device != null) Marshal.ReleaseComObject(device);
            if (enumerator != null) Marshal.ReleaseComObject(enumerator);
        }
    }

    static IAudioEndpointVolume GetDefaultInputVolume(ERole role, out IMMDeviceEnumerator enumerator, out IMMDevice device) {
        enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
        if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eCapture, role, out device) != 0) throw new InvalidOperationException("Nincs alapértelmezett mikrofon.");
        Guid iid = typeof(IAudioEndpointVolume).GUID; IntPtr instance;
        if (device.Activate(ref iid, 23, IntPtr.Zero, out instance) != 0 || instance == IntPtr.Zero) throw new InvalidOperationException("A mikrofon hangereje nem érhető el.");
        var volume = (IAudioEndpointVolume)Marshal.GetObjectForIUnknown(instance); Marshal.Release(instance); return volume;
    }

    public static float GetDefaultInputVolumePercent() {
        IMMDeviceEnumerator enumerator = null; IMMDevice device = null; IAudioEndpointVolume volume = null;
        try { volume = GetDefaultInputVolume(ERole.eConsole, out enumerator, out device); float level; return volume.GetMasterVolumeLevelScalar(out level) == 0 ? Math.Max(0, Math.Min(100, level * 100)) : 0; }
        catch { return 0; }
        finally { if (volume != null) Marshal.ReleaseComObject(volume); if (device != null) Marshal.ReleaseComObject(device); if (enumerator != null) Marshal.ReleaseComObject(enumerator); }
    }

    public static bool SetDefaultInputVolumePercent(float percent) {
        float target = Math.Max(0, Math.Min(1, percent / 100f));
        bool applied = false;
        foreach (ERole role in new[] { ERole.eConsole, ERole.eMultimedia, ERole.eCommunications }) {
            IMMDeviceEnumerator enumerator = null; IMMDevice device = null; IAudioEndpointVolume volume = null;
            try {
                volume = GetDefaultInputVolume(role, out enumerator, out device);
                Guid context = Guid.Empty;
                if (volume.SetMasterVolumeLevelScalar(target, ref context) == 0) {
                    float confirmed;
                    if (volume.GetMasterVolumeLevelScalar(out confirmed) == 0 && Math.Abs(confirmed - target) <= 0.02f) applied = true;
                }
            } catch { }
            finally { if (volume != null) Marshal.ReleaseComObject(volume); if (device != null) Marshal.ReleaseComObject(device); if (enumerator != null) Marshal.ReleaseComObject(enumerator); }
        }
        return applied;
    }
}
"@

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LicenseDeviceId {
    try {
        $machineGuid = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid -ErrorAction Stop).MachineGuid
    } catch {
        $machineGuid = "fallback:$env:COMPUTERNAME:$env:PROCESSOR_IDENTIFIER"
    }
    $raw = "$machineGuid|$($script:licenseProductId)|SoundLift"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($raw)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Protect-LicenseState([object]$state) {
    $plain = [Text.Encoding]::UTF8.GetBytes(($state | ConvertTo-Json -Compress))
    $protected = [Security.Cryptography.ProtectedData]::Protect($plain, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    return [Convert]::ToBase64String($protected)
}

function Unprotect-LicenseState([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $null }
    $protected = [Convert]::FromBase64String($value)
    $plain = [Security.Cryptography.ProtectedData]::Unprotect($protected, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    return ([Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json)
}

function Get-InstallationProof {
    $path = Join-Path $script:logRoot 'installation-proof.dat'
    if (Test-Path $path) { return [string](Unprotect-LicenseState ([IO.File]::ReadAllText($path))).proof }
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    $proof = ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
    [IO.File]::WriteAllText($path, (Protect-LicenseState @{proof=$proof}), [Text.Encoding]::UTF8)
    return $proof
}

function Get-SoundLiftFunctionUrl([string]$functionName) {
    if ([string]::IsNullOrWhiteSpace($script:logApiUrl)) { throw 'A SoundLift kiszolgálója nincs beállítva.' }
    return [Regex]::Replace($script:logApiUrl.TrimEnd('/'), '/[^/]+$', "/$functionName")
}

function Invoke-DiscordLinkApi([string]$functionName) {
    $headers = @{ 'Content-Type'='application/json'; 'User-Agent'="SoundLift/$($script:appVersion)" }
    if (-not [string]::IsNullOrWhiteSpace($script:logAnonKey)) {
        $headers.apikey = $script:logAnonKey
        $headers.Authorization = "Bearer $($script:logAnonKey)"
    }
    $body = @{ installation_id=$script:installationId; installation_proof=(Get-InstallationProof) } | ConvertTo-Json -Compress
    return Invoke-RestMethod -Uri (Get-SoundLiftFunctionUrl $functionName) -Method Post -Headers $headers -Body $body -TimeoutSec 12
}

function Get-DiscordLinkCache {
    $path = Join-Path $script:logRoot 'discord-link.dat'
    if (-not (Test-Path $path)) { return $null }
    try { return Unprotect-LicenseState ([IO.File]::ReadAllText($path)) } catch { return $null }
}

function Save-DiscordLinkCache([string]$supportId) {
    try {
        $state = [PSCustomObject]@{ linked=$true; installationId=$script:installationId; supportId=$supportId; lastVerifiedUtc=[DateTime]::UtcNow.ToString('o') }
        [IO.File]::WriteAllText((Join-Path $script:logRoot 'discord-link.dat'), (Protect-LicenseState $state), [Text.Encoding]::UTF8)
    } catch { }
}

function Test-DiscordLinkOfflineGrace {
    $cached = Get-DiscordLinkCache
    if (-not $cached -or $cached.linked -ne $true -or $cached.installationId -ne $script:installationId -or -not $cached.lastVerifiedUtc) { return $false }
    try { $age = ([DateTime]::UtcNow - [DateTime]::Parse([string]$cached.lastVerifiedUtc).ToUniversalTime()).TotalHours; return ($age -ge 0 -and $age -le $script:discordLinkGraceHours) } catch { return $false }
}

function Confirm-DiscordAccountLink {
    if (-not $script:discordLinkRequired) { return $true }
    # A DPAPI-val védett, korábban sikeresen ellenőrzött kapcsolat azonnal
    # használható. Így az internet sebessége nem blokkolja a főablak indulását.
    if (Test-DiscordLinkOfflineGrace) { return $true }
    try {
        $status = Invoke-DiscordLinkApi 'discord-link-status'
        if ($status.linked -eq $true) { Save-DiscordLinkCache ([string]$status.support_id); return $true }
        $cachePath = Join-Path $script:logRoot 'discord-link.dat'
        if (Test-Path $cachePath) { [IO.File]::Delete($cachePath) }
    } catch {
        if ((-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ge 500) -and (Test-DiscordLinkOfflineGrace)) {
            Write-SoundLiftLog -Category security -EventName 'discord_link_offline_grace_used' -Severity warning -Data @{ grace_hours=$script:discordLinkGraceHours }
            return $true
        }
        Write-SoundLiftLog -Category security -EventName 'discord_link_check_failed' -Severity error -ErrorRecord $_
        Show-SoundLiftMessage 'A Discord-összekapcsolás ellenőrzése sikertelen. Helyi alkalmazáshiba vagy szerverkapcsolati hiba is okozhatja. A részletek a SoundLift logs mappájában találhatók.' 'SoundLift – Discord ellenőrzés' 'OK' 'Error' | Out-Null
        return $false
    }

    Write-SoundLiftLog -Category security -EventName 'discord_link_required' -Severity warning
    $dialog = [Windows.Window]::new(); $dialog.Title='SoundLift – Discord összekapcsolás'; $dialog.Width=610; $dialog.Height=430
    $dialog.ResizeMode='NoResize'; $dialog.WindowStartupLocation='CenterScreen'; Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.StackPanel]::new(); $root.Margin=[Windows.Thickness]::new(30)
    $title=[Windows.Controls.TextBlock]::new(); $title.Text='Discord-fiók összekapcsolása'; $title.FontSize=24; $title.FontWeight='Bold'
    $info=[Windows.Controls.TextBlock]::new(); $info.Text="A SoundLift használatához hitelesítened kell a Discord-fiókodat.`nA kapcsolat a frissítések után is megmarad."; $info.TextWrapping='Wrap'; $info.Margin=[Windows.Thickness]::new(0,14,0,12); $info.Foreground='#CBD5E1'
    $privacy=[Windows.Controls.TextBlock]::new(); $privacy.Text='A rendszer a Discord felhasználói azonosítódat és megjelenített nevedet tárolja a telepítés azonosításához, támogatáshoz és biztonsági naplózáshoz. Jelszót, üzeneteket és szerverlistát nem olvas.'; $privacy.TextWrapping='Wrap'; $privacy.Margin=[Windows.Thickness]::new(0,0,0,18); $privacy.Foreground='#94A3B8'
    $statusText=[Windows.Controls.TextBlock]::new(); $statusText.Text='Kattints az összekapcsolásra, engedélyezd a Discord-oldalon, majd térj vissza ide.'; $statusText.TextWrapping='Wrap'; $statusText.Margin=[Windows.Thickness]::new(0,0,0,18); $statusText.Foreground='#FBBF24'
    $connect=[Windows.Controls.Button]::new(); $connect.Content='Discord összekapcsolása'; $connect.Height=44; $connect.Margin=[Windows.Thickness]::new(0,0,0,10)
    $verify=[Windows.Controls.Button]::new(); $verify.Content='Összekapcsolás ellenőrzése'; $verify.Height=44; $verify.Margin=[Windows.Thickness]::new(0,0,0,10)
    $cancel=[Windows.Controls.Button]::new(); $cancel.Content='Kilépés'; $cancel.Height=38
    $result=@{ linked=$false }
    $connect.Add_Click({
        try {
            $created=Invoke-DiscordLinkApi 'discord-link-create'
            if ($created.linked -eq $true) { Save-DiscordLinkCache ([string]$created.support_id); $result.linked=$true; $dialog.Close(); return }
            if ([string]::IsNullOrWhiteSpace([string]$created.authorization_url)) { throw 'A kiszolgáló nem adott engedélyezési linket.' }
            $authUri = [Uri]([string]$created.authorization_url)
            if ($authUri.Scheme -ne 'https' -or $authUri.Host -ne 'discord.com' -or $authUri.AbsolutePath -ne '/oauth2/authorize') { throw 'Érvénytelen Discord-link.' }
            Start-Process $authUri.AbsoluteUri
            $statusText.Text='A Discord-oldal megnyílt. Engedélyezés után kattints az ellenőrzés gombra.'
        } catch { $statusText.Text="Az összekapcsolás nem indítható: $($_.Exception.Message)" }
    }.GetNewClosure())
    $verify.Add_Click({
        try {
            $checked=Invoke-DiscordLinkApi 'discord-link-status'
            if ($checked.linked -eq $true) { Save-DiscordLinkCache ([string]$checked.support_id); $result.linked=$true; $dialog.Close() }
            else { $statusText.Text='Még nincs kész az összekapcsolás. Engedélyezd a Discord-oldalon, majd próbáld újra.' }
        } catch { $statusText.Text="Az ellenőrzés sikertelen: $($_.Exception.Message)" }
    }.GetNewClosure())
    $cancel.Add_Click({ $dialog.Close() }.GetNewClosure())
    foreach ($control in @($title,$info,$privacy,$statusText,$connect,$verify,$cancel)) { [void]$root.Children.Add($control) }
    $dialog.Content=$root; [void]$dialog.ShowDialog()
    if ($result.linked) { Write-SoundLiftLog -Category security -EventName 'discord_link_succeeded'; return $true }
    Write-SoundLiftLog -Category security -EventName 'discord_link_cancelled' -Severity warning
    return $false
}

function Get-SavedLicenseState {
    $path = Join-Path $env:APPDATA 'SoundLift\license.dat'
    if (-not (Test-Path $path)) { return $null }
    try { return Unprotect-LicenseState ([IO.File]::ReadAllText($path)) } catch { return $null }
}

function Save-LicenseState([string]$licenseKey, [string]$licenseType, [string]$authorizationId, [object[]]$features, [bool]$isOwner, [string]$licenseStatus = 'active', [string]$licenseVariant = '', [string]$activatedUtc = '', [string]$deviceRef = '') {
    $directory = Join-Path $env:APPDATA 'SoundLift'
    if (-not (Test-Path $directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    $state = [PSCustomObject]@{ key=$licenseKey.Trim(); licenseType=$licenseType; authorizationId=$authorizationId; features=@($features); isOwner=$isOwner; licenseStatus=$licenseStatus; licenseVariant=$licenseVariant; activatedUtc=$activatedUtc; deviceRef=$deviceRef; lastSuccessUtc=[DateTime]::UtcNow.ToString('o') }
    [IO.File]::WriteAllText((Join-Path $directory 'license.dat'), (Protect-LicenseState $state), [Text.Encoding]::UTF8)
}

function Remove-LicenseState {
    $path = Join-Path $env:APPDATA 'SoundLift\license.dat'
    if (Test-Path $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    $script:currentLicenseType = 'free'
    $script:currentLicenseStatus = 'inactive'; $script:currentLicenseVariant = 'ingyenes'; $script:currentLicenseActivatedUtc = ''; $script:currentLicenseDeviceRef = ''
    $script:isOwner = $false; $script:licenseFeatures = @{}; $script:simulatedLicenseLabel = ''
}

function Invoke-LicenseApi([string]$licenseKey, [string]$action = 'verify', [string]$simulationLicenseId = '') {
    if ([string]::IsNullOrWhiteSpace($script:licenseApiUrl) -or [string]::IsNullOrWhiteSpace($script:licenseProductId)) {
        throw 'A SoundLift licenckiszolgálója nincs beállítva.'
    }
    $headers = @{ 'Content-Type' = 'application/json'; 'User-Agent' = "SoundLift/$($script:appVersion)" }
    if (-not [string]::IsNullOrWhiteSpace($script:licenseAnonKey)) {
        $headers['apikey'] = $script:licenseAnonKey
        $headers['Authorization'] = "Bearer $($script:licenseAnonKey)"
    }
    $buildChannel = if ($script:licenseMode -eq 'custom') { 'customer' } else { 'public' }
    $requestData = @{ license_key=$licenseKey.Trim(); product_id=$script:licenseProductId; device_id=Get-LicenseDeviceId; installation_id=$script:installationId; installation_proof=(Get-InstallationProof); action=$action; app_version=$script:appVersion; build_channel=$buildChannel }
    if (-not [string]::IsNullOrWhiteSpace($simulationLicenseId)) { $requestData.simulation_license_id=$simulationLicenseId }
    $body = $requestData | ConvertTo-Json -Compress
    try {
        return Invoke-RestMethod -Uri $script:licenseApiUrl -Method Post -Headers $headers -Body $body -TimeoutSec 12
    } catch {
        # Windows PowerShell 5.1 a szabályos 4xx licencválaszt is kivételként adja.
        # Ezt visszaalakítjuk válaszobjektummá, hogy egy letiltott kulcs soha ne
        # essen bele tévesen az offline türelmi időbe.
        $webResponse = $_.Exception.Response
        if ($webResponse) {
            try {
                $statusCode = [int]$webResponse.StatusCode
                if ($statusCode -ge 400 -and $statusCode -lt 500) {
                    $reader = New-Object IO.StreamReader($webResponse.GetResponseStream())
                    try { return ($reader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop) } finally { $reader.Dispose() }
                }
            } catch { }
        }
        throw
    }
}

function Set-LicenseFeatures([object[]]$features) {
    $script:licenseFeatures = @{}
    foreach ($feature in @($features)) {
        $key = [string]$feature.feature_key
        if ($key -match '^[a-z][a-z0-9_]{2,63}$') { $script:licenseFeatures[$key] = $feature }
    }
}

function Set-LicenseResponse([object]$response, [switch]$Persist, [string]$licenseKey = '') {
    $script:currentLicenseType = if ($response.license_type) { [string]$response.license_type } else { 'customer' }
    $script:isOwner = ($response.is_owner -eq $true)
    $script:currentLicenseStatus = if ($response.license_status) { [string]$response.license_status } else { 'active' }
    $script:currentLicenseVariant = if ($response.license_variant) { [string]$response.license_variant } elseif ($script:currentLicenseType -eq 'developer') { 'fejlesztői' } else { 'normál' }
    $script:currentLicenseActivatedUtc = [string]$response.activated_at
    $script:currentLicenseDeviceRef = [string]$response.device_ref
    Set-LicenseFeatures @($response.features)
    $script:simulatedLicenseLabel = if ($response.simulated_license) { [string]$response.simulated_license.label } else { '' }
    if ($Persist -and -not [string]::IsNullOrWhiteSpace($licenseKey) -and -not $response.simulated_license) {
        Save-LicenseState $licenseKey $script:currentLicenseType ([string]$response.authorization_id) @($response.features) $script:isOwner $script:currentLicenseStatus $script:currentLicenseVariant $script:currentLicenseActivatedUtc $script:currentLicenseDeviceRef
    }
}

function Show-LicenseKeyDialog {
    $dialog = [Windows.Window]::new(); $dialog.Title = 'SoundLift – Licencaktiválás'; $dialog.Width = 560; $dialog.Height = 350
    $dialog.ResizeMode = 'NoResize'; $dialog.WindowStartupLocation = 'CenterOwner'; $dialog.Owner=$window; Set-SoundLiftWindowStyle $dialog
    $root = [Windows.Controls.StackPanel]::new(); $root.Margin = [Windows.Thickness]::new(28)
    $title = [Windows.Controls.TextBlock]::new(); $title.Text = 'Vásárlói licenc aktiválása'; $title.FontSize = 23; $title.FontWeight = 'Bold'
    $info = [Windows.Controls.TextBlock]::new(); $info.Text = "Írd be a vásárláskor kapott licenckulcsot.`nA kulcs az első sikeres aktiváláskor ehhez a számítógéphez kapcsolódik."; $info.TextWrapping = 'Wrap'; $info.Margin = [Windows.Thickness]::new(0,12,0,16); $info.Foreground = '#CBD5E1'
    $licenseInput = [Windows.Controls.TextBox]::new(); $licenseInput.Height = 38; $licenseInput.Padding = [Windows.Thickness]::new(8); $licenseInput.FontSize = 14
    $status=[Windows.Controls.TextBlock]::new();$status.Text='Illeszd be a teljes, SL- kezdetű kulcsot.';$status.Foreground='#94A3B8';$status.Margin=[Windows.Thickness]::new(0,8,0,0)
    $buttons = [Windows.Controls.StackPanel]::new(); $buttons.Orientation = 'Horizontal'; $buttons.HorizontalAlignment = 'Right'; $buttons.Margin = [Windows.Thickness]::new(0,18,0,0)
    $cancel = [Windows.Controls.Button]::new(); $cancel.Content = 'Mégse'; $cancel.Width = 100; $cancel.Height = 38; $cancel.Margin = [Windows.Thickness]::new(0,0,10,0)
    $activate = [Windows.Controls.Button]::new(); $activate.Content = 'Licenc aktiválása'; $activate.Width = 150; $activate.Height = 38; $activate.IsDefault=$true
    $cancel.IsCancel=$true; $dialog.Tag=$null
    $cancel.Add_Click({$dialog.DialogResult=$false}.GetNewClosure())
    $activate.Add_Click({
        $candidate=[string]$licenseInput.Text
        # LICENSE_DIALOG_INVALID_KEY: a teljes kimásolt konzolsorból is
        # biztonságosan csak a szabályos SoundLift-kulcsot vesszük át.
        $keyMatch=[Regex]::Match($candidate,'(?i)SL-[A-F0-9]{32}')
        if(-not $keyMatch.Success){$status.Text='Nem található teljes SoundLift-licenckulcs. A kulcs formátuma: SL- és 32 karakter.';$status.Foreground='#FB7185';return}
        $dialog.Tag=$keyMatch.Value.ToUpperInvariant();$dialog.DialogResult=$true
    }.GetNewClosure())
    $buttons.Children.Add($cancel) | Out-Null; $buttons.Children.Add($activate) | Out-Null
    $root.Children.Add($title) | Out-Null; $root.Children.Add($info) | Out-Null; $root.Children.Add($licenseInput) | Out-Null; $root.Children.Add($status)|Out-Null; $root.Children.Add($buttons) | Out-Null
    $dialog.Content=$root;$licenseInput.Focus()|Out-Null
    if($dialog.ShowDialog()-eq $true){return [string]$dialog.Tag};return $null
}

function Confirm-SoundLiftLicense {
    param([switch]$PromptForKey)
    if ($script:licenseMode -notin @('universal','custom')) { return $true }
    $saved = Get-SavedLicenseState
    $key = if ($PromptForKey) { Show-LicenseKeyDialog } elseif ($saved -and $saved.key) { [string]$saved.key } else { $null }
    if ([string]::IsNullOrWhiteSpace($key)) {
        if ($PromptForKey) {
            Write-SoundLiftLog -Category license -EventName 'activation_cancelled' -Severity warning
            return $false
        }
        $script:currentLicenseType = 'free'
        return (-not $PromptForKey -and $script:licenseMode -eq 'universal')
    }
    if (-not $PromptForKey -and $saved -and $saved.lastSuccessUtc) {
        try {
            $cachedAge = ([DateTime]::UtcNow - [DateTime]::Parse([string]$saved.lastSuccessUtc).ToUniversalTime()).TotalHours
            # Rövid gyorsítótár: a legtöbb indítás azonnali, de az új vagy
            # visszavont feature flagek legfeljebb egy órán belül frissülnek.
            if ($cachedAge -ge 0 -and $cachedAge -le 1) {
                $script:currentLicenseType = if ($saved.licenseType) { [string]$saved.licenseType } else { 'customer' }
                $script:currentLicenseStatus = if ($saved.licenseStatus) { [string]$saved.licenseStatus } else { 'active' }
                $script:currentLicenseVariant = if ($saved.licenseVariant) { [string]$saved.licenseVariant } elseif ($script:currentLicenseType -eq 'developer') { 'fejlesztői' } else { 'normál' }
                $script:currentLicenseActivatedUtc = [string]$saved.activatedUtc; $script:currentLicenseDeviceRef = [string]$saved.deviceRef
                $script:isOwner = ($saved.isOwner -eq $true); Set-LicenseFeatures @($saved.features)
                return $true
            }
        } catch { }
    }
    try {
        $response = Invoke-LicenseApi $key
        if ($response.allowed -eq $true) {
            Set-LicenseResponse $response -Persist -licenseKey $key
            # A sikeres online licencellenőrzést a megbízható backend naplózza
            # részletesen és naponta deduplikálva. A kliens nem küld róla
            # második eseményt, így a Supabase- és Discord-használat alacsony marad.
            return $true
        }
        $failureCode = ConvertTo-SoundLiftSafeText $response.code 60
        Write-SoundLiftLog -Category license -EventName 'validation_failed' -Severity warning -Data @{ code=$failureCode }
        if ($failureCode -in @('INVALID_LICENSE','LICENSE_BLOCKED','LICENSE_EXPIRED','DEVICE_LIMIT')) {
            Write-SoundLiftLog -Category security -EventName 'license_rejected' -Severity warning -Data @{ code=$failureCode }
        }
        if (-not $PromptForKey) { Remove-LicenseState }
        Show-SoundLiftMessage ([string]$response.message) 'A licenc nem használható' 'OK' 'Warning' $window | Out-Null
        return (-not $PromptForKey -and $script:licenseMode -eq 'universal')
    } catch {
        # Rövid internetkimaradásnál 72 órás, DPAPI-val védett türelmi idő.
        if (-not $PromptForKey -and $saved -and $saved.lastSuccessUtc) {
            try {
                if (([DateTime]::UtcNow - [DateTime]::Parse([string]$saved.lastSuccessUtc).ToUniversalTime()).TotalHours -le 72) {
                    $script:currentLicenseType = if ($saved.licenseType) { [string]$saved.licenseType } else { 'customer' }
                    $script:currentLicenseStatus = if ($saved.licenseStatus) { [string]$saved.licenseStatus } else { 'active' }
                    $script:currentLicenseVariant = if ($saved.licenseVariant) { [string]$saved.licenseVariant } elseif ($script:currentLicenseType -eq 'developer') { 'fejlesztői' } else { 'normál' }
                    $script:currentLicenseActivatedUtc = [string]$saved.activatedUtc; $script:currentLicenseDeviceRef = [string]$saved.deviceRef
                    $script:isOwner = ($saved.isOwner -eq $true); Set-LicenseFeatures @($saved.features)
                    $offlineFeatures = @($saved.features | ForEach-Object { [string]$_.feature_key } | Where-Object { $_ }) -join ', '
                    $offlineVariant = if ($script:currentLicenseType -eq 'developer') { 'fejlesztői' } elseif ($offlineFeatures) { 'egyedi' } else { 'normál' }
                    $offlineBuildChannel = if ($script:licenseMode -eq 'custom') { 'customer' } else { 'public' }
                    Write-SoundLiftLog -Category license -EventName 'offline_grace_used' -Severity warning -Data @{ grace_hours=72; license_type=$script:currentLicenseType; license_variant=$offlineVariant; current_version=$script:appVersion; build_channel=$offlineBuildChannel; server_check='offline'; feature_permissions=$(if($offlineFeatures){$offlineFeatures}else{'nincs'}) }
                    return $true
                }
            } catch { }
        }
        Write-SoundLiftLog -Category license -EventName 'validation_unavailable' -Severity error -ErrorRecord $_
        if ($PromptForKey -or $script:licenseMode -eq 'custom') {
            Show-SoundLiftMessage "A licenc most nem ellenőrizhető, és nincs érvényes offline időszak.`n`n$($_.Exception.Message)" 'Licencellenőrzési hiba' 'OK' 'Error' $window | Out-Null
        }
        if (-not $PromptForKey) { $script:currentLicenseType = 'free' }
        return (-not $PromptForKey -and $script:licenseMode -eq 'universal')
    }
}

function Get-ApoConfigDirectory {
    $candidates = @(
        "$env:ProgramFiles\EqualizerAPO\config",
        "${env:ProgramFiles(x86)}\EqualizerAPO\config"
    ) | Where-Object { $_ -and (Test-Path $_) }
    return $candidates | Select-Object -First 1
}

# Authenticate before creating controls, tray actions, timers or hotkeys.
if (-not (Confirm-DiscordAccountLink)) {
    Write-SoundLiftLog -Category startup -EventName 'initialization_failed' -Severity warning -Data @{stage='discord_link_gate'}
    [void](Send-SoundLiftPendingLogs)
    return
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SoundLift V1.6.0" Width="1220" Height="880" MinWidth="1040" MinHeight="740"
        WindowStartupLocation="CenterScreen" Background="#070707" Foreground="{DynamicResource PrimaryTextBrush}"
        FontFamily="Segoe UI" ResizeMode="CanResizeWithGrip" ShowInTaskbar="True"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
  <Window.Resources>
    <LinearGradientBrush x:Key="PageGradient" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#070707" Offset="0"/><GradientStop Color="#20090B" Offset="0.55"/><GradientStop Color="#070707" Offset="1"/>
    </LinearGradientBrush>
    <LinearGradientBrush x:Key="AccentGradient" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#EF233C" Offset="0"/><GradientStop Color="#8B0017" Offset="1"/>
    </LinearGradientBrush>
    <SolidColorBrush x:Key="AccentTextBrush" Color="#FF4057"/>
    <SolidColorBrush x:Key="HoverBrush" Color="#3A1016"/>
    <SolidColorBrush x:Key="SurfaceBrush" Color="#111113"/>
    <SolidColorBrush x:Key="SurfaceAltBrush" Color="#0B0B0D"/>
    <SolidColorBrush x:Key="ControlBrush" Color="#17171B"/>
    <SolidColorBrush x:Key="BorderBrush" Color="#29292E"/>
    <SolidColorBrush x:Key="PrimaryTextBrush" Color="#F8FAFC"/>
    <SolidColorBrush x:Key="SecondaryTextBrush" Color="#CBD5E1"/>
    <SolidColorBrush x:Key="MutedTextBrush" Color="#64748B"/>
    <SolidColorBrush x:Key="SectionTextBrush" Color="#9A7C80"/>
    <SolidColorBrush x:Key="AccentContrastBrush" Color="#FFFFFF"/>
    <DropShadowEffect x:Key="CardShadow" BlurRadius="22" ShadowDepth="4" Opacity="0.25" Color="#000000"/>
    <Style TargetType="TextBlock"><Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/></Style>
    <Style TargetType="Button">
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/><Setter Property="FontSize" Value="13"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/><Setter Property="Background" Value="{DynamicResource ControlBrush}"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="15,10"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="0,0,0,8"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <TextBlock Text="{TemplateBinding Content}" Foreground="{DynamicResource PrimaryTextBrush}" FontFamily="{TemplateBinding FontFamily}" FontSize="{TemplateBinding FontSize}" FontWeight="{TemplateBinding FontWeight}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Background" Value="{DynamicResource HoverBrush}"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.72"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="{DynamicResource AccentGradient}"/><Setter Property="Foreground" Value="{DynamicResource AccentContrastBrush}"/>
      <Setter Property="FontSize" Value="15"/><Setter Property="Padding" Value="24,14"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="ButtonBorder" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
              <TextBlock Text="{TemplateBinding Content}" Foreground="{DynamicResource AccentContrastBrush}" FontFamily="{TemplateBinding FontFamily}" FontSize="{TemplateBinding FontSize}" FontWeight="{TemplateBinding FontWeight}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.88"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.72"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="ButtonBorder" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="UtilityButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="{DynamicResource ControlBrush}"/><Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="13,9"/><Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="HorizontalContentAlignment" Value="Center"/>
    </Style>
    <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource UtilityButton}">
      <Setter Property="Foreground" Value="#FF7A8A"/><Setter Property="Background" Value="#241014"/>
      <Setter Property="BorderBrush" Value="#5A2029"/><Setter Property="Padding" Value="16,10"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="FontFamily" Value="Segoe UI"/><Setter Property="FontSize" Value="13"/>
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/><Setter Property="Background" Value="{DynamicResource ControlBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="11,8"/><Setter Property="CaretBrush" Value="{DynamicResource AccentTextBrush}"/>
    </Style>
    <Style TargetType="ListBox">
      <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/><Setter Property="Background" Value="{DynamicResource SurfaceAltBrush}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush}"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="6"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource SecondaryTextBrush}"/><Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,4,18,4"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Border x:Name="CheckBorder" Width="15" Height="15" CornerRadius="4" Background="{DynamicResource SurfaceAltBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1.5" VerticalAlignment="Center"/>
              <TextBlock x:Name="CheckMark" Text="✓" Foreground="{DynamicResource AccentContrastBrush}" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
              <TextBlock Grid.Column="1" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}" FontSize="{TemplateBinding FontSize}" Margin="5,0,0,0" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True"><Setter TargetName="CheckBorder" Property="Background" Value="{DynamicResource AccentTextBrush}"/><Setter TargetName="CheckBorder" Property="BorderBrush" Value="{DynamicResource AccentTextBrush}"/><Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/></Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="CheckBorder" Property="BorderBrush" Value="{DynamicResource AccentTextBrush}"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Slider">
      <Setter Property="Height" Value="32"/><Setter Property="Margin" Value="0,7,0,5"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Slider">
            <Grid>
              <Border Height="6" CornerRadius="3" Background="{DynamicResource ControlBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" VerticalAlignment="Center"/>
              <Track Name="PART_Track" VerticalAlignment="Center">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="Slider.DecreaseLarge" Background="{DynamicResource AccentGradient}" BorderThickness="0">
                    <RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Height="6" Background="{TemplateBinding Background}" CornerRadius="3"/></ControlTemplate></RepeatButton.Template>
                  </RepeatButton>
                </Track.DecreaseRepeatButton>
                <Track.Thumb>
                  <Thumb Width="20" Height="20" Cursor="Hand">
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Grid><Ellipse Fill="{DynamicResource SurfaceBrush}" Stroke="{DynamicResource AccentTextBrush}" StrokeThickness="3"/><Ellipse Width="6" Height="6" Fill="{DynamicResource AccentTextBrush}"/></Grid>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
                <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Background="Transparent" BorderThickness="0"/></Track.IncreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="VerticalEqSlider" TargetType="Slider">
      <Setter Property="Width" Value="32"/><Setter Property="Height" Value="120"/>
      <Setter Property="Margin" Value="2"/><Setter Property="Orientation" Value="Vertical"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Slider">
            <Grid>
              <Border Width="6" CornerRadius="3" Background="{DynamicResource ControlBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" HorizontalAlignment="Center"/>
              <Track Name="PART_Track" Orientation="Vertical" IsDirectionReversed="True" HorizontalAlignment="Center">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="Slider.DecreaseLarge" Background="Transparent" BorderThickness="0"/>
                </Track.DecreaseRepeatButton>
                <Track.Thumb>
                  <Thumb Width="20" Height="14" Cursor="Hand">
                    <Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="{DynamicResource SurfaceBrush}" BorderBrush="{DynamicResource AccentTextBrush}" BorderThickness="3" CornerRadius="7"/></ControlTemplate></Thumb.Template>
                  </Thumb>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="Slider.IncreaseLarge" Background="{DynamicResource AccentTextBrush}" BorderThickness="0">
                    <RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Width="6" Background="{TemplateBinding Background}" CornerRadius="3"/></ControlTemplate></RepeatButton.Template>
                  </RepeatButton>
                </Track.IncreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Background="{DynamicResource PageGradient}">
    <Grid.RowDefinitions><RowDefinition Height="96"/><RowDefinition Height="*"/></Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="30,20,30,13">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="440"/></Grid.ColumnDefinitions>
      <StackPanel VerticalAlignment="Center">
        <TextBlock Text="SOUNDLIFT" FontFamily="Segoe UI Black" FontSize="29" Foreground="{DynamicResource AccentTextBrush}"/>
        <TextBlock Text="WINDOWS HANGVEZÉRLŐ  •  V1.6.0" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource MutedTextBrush}" Margin="1,3,0,0"/>
      </StackPanel>
      <Border Name="StatusBorder" Grid.Column="1" Background="{DynamicResource SurfaceBrush}" CornerRadius="15" Padding="17,12" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}">
        <StackPanel>
          <TextBlock Name="StatusText" Text="A hangrendszer ellenőrzése folyamatban…" FontSize="13" FontWeight="SemiBold" Foreground="{DynamicResource PrimaryTextBrush}"/>
          <TextBlock Name="DeviceText" Text="Aktív hangkimenet észlelése…" FontSize="12" Foreground="{DynamicResource MutedTextBrush}" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </Border>
    </Grid>

    <Grid Grid.Row="1" Margin="30,0,30,28">
      <Grid.ColumnDefinitions><ColumnDefinition Width="245"/><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>

      <Border Grid.Column="0" Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="16" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}">
        <Grid>
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
          <TextBlock Text="HANGPROFILOK" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}" Margin="5,2,0,13"/>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Hidden" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly" Margin="0,0,0,4">
          <StackPanel Name="ProfilePanel">
            <Button Name="MusicButton" Content="♫   Zene"/>
            <Button Name="GameButton" Content="◆   FiveM RP"/>
            <Button Name="CombatButton" Content="⌁   FiveM PvP"/>
            <Button Name="R6Button" Content="◎   Rainbow Six Siege"/>
            <Button Name="DiscordButton" Content="◉   Discord"/>
            <Button Name="MovieButton" Content="▶   Film"/>
            <Button Name="HeavyButton" Content="ϟ   Erőteljes basszus"/>
            <Button Name="ResetButton" Content="↺   Alapbeállítások"/>
            <TextBlock Name="CustomFeaturesTitle" Text="EGYEDI FUNKCIÓK" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}" Margin="4,12,0,5" Visibility="Collapsed"/>
            <Button Name="ExtraBassProButton" Content="✦   Extra mélyhang Pro" Visibility="Collapsed"/>
            <Button Name="VoiceBoostButton" Content="◈   Beszédkiemelés" Visibility="Collapsed"/>
            <Button Name="CustomPresetXButton" Content="◆   Egyéni profil X" Visibility="Collapsed"/>
            <Button Name="ProfileOrderButton" Content="☰   Profilok rendezése" Style="{StaticResource UtilityButton}" Margin="0,10,0,4"/>
          </StackPanel>
          </ScrollViewer>
          <StackPanel Grid.Row="2">
            <Border Height="1" Background="#303035" Margin="0,4,0,13"/>
            <TextBlock Text="MEGJELENÉS" FontSize="10" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}" Margin="4,0,0,5"/>
            <ComboBox Name="ThemeCombo" Height="34" Margin="0,0,0,9" Padding="8,3"
                      Background="{DynamicResource ControlBrush}" Foreground="{DynamicResource PrimaryTextBrush}" BorderBrush="{DynamicResource BorderBrush}" FontWeight="SemiBold">
              <ComboBox.Template>
                <ControlTemplate TargetType="{x:Type ComboBox}">
                  <Grid>
                    <ToggleButton Focusable="False" ClickMode="Press"
                                  IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                      <ToggleButton.Template>
                        <ControlTemplate TargetType="{x:Type ToggleButton}">
                          <Border x:Name="ThemeBorder" Background="{DynamicResource ControlBrush}" BorderBrush="{DynamicResource BorderBrush}"
                                  BorderThickness="1" CornerRadius="5">
                            <Grid>
                              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="30"/></Grid.ColumnDefinitions>
                              <Path Grid.Column="1" Width="8" Height="5" HorizontalAlignment="Center" VerticalAlignment="Center"
                                    Fill="#CBD5E1" Data="M 0 0 L 4 4 L 8 0 Z"/>
                            </Grid>
                          </Border>
                          <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ThemeBorder" Property="BorderBrush" Value="{DynamicResource AccentTextBrush}"/></Trigger>
                          </ControlTemplate.Triggers>
                        </ControlTemplate>
                      </ToggleButton.Template>
                    </ToggleButton>
                    <TextBlock Margin="11,0,34,0" VerticalAlignment="Center" HorizontalAlignment="Left"
                               IsHitTestVisible="False" Text="{TemplateBinding SelectionBoxItem}"
                               Foreground="{DynamicResource PrimaryTextBrush}" TextTrimming="CharacterEllipsis"/>
                    <Popup Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                           AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                      <Border Margin="0,3,0,0" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="180"
                              Background="{DynamicResource SurfaceBrush}" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" CornerRadius="5">
                        <ScrollViewer Margin="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                          <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                        </ScrollViewer>
                      </Border>
                    </Popup>
                  </Grid>
                </ControlTemplate>
              </ComboBox.Template>
              <ComboBox.Resources>
                <Style TargetType="{x:Type ComboBoxItem}">
                  <Setter Property="Foreground" Value="{DynamicResource PrimaryTextBrush}"/>
                  <Setter Property="Background" Value="{DynamicResource ControlBrush}"/>
                  <Setter Property="Padding" Value="9,6"/>
                  <Style.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="{DynamicResource HoverBrush}"/></Trigger>
                    <Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="{DynamicResource AccentTextBrush}"/><Setter Property="Foreground" Value="{DynamicResource AccentContrastBrush}"/></Trigger>
                  </Style.Triggers>
                </Style>
              </ComboBox.Resources>
            </ComboBox>
            <TextBlock Name="VersionText" Text="Telepített verzió: 1.6.0" Foreground="{DynamicResource MutedTextBrush}" FontSize="11" Margin="4,0,0,6"/>
            <TextBlock Name="SupportIdText" Text="Támogatási ID: betöltés…" Foreground="{DynamicResource MutedTextBrush}" FontSize="11" Margin="4,0,0,4"/>
            <Button Name="CopySupportIdButton" Content="⧉  Támogatási ID másolása" Style="{StaticResource UtilityButton}"/>
            <TextBlock Name="LicenseStatusText" Text="Licenc: ingyenes" Foreground="{DynamicResource MutedTextBrush}" FontSize="11" Margin="4,5,0,4"/>
            <Button Name="LicenseButton" Content="◇  Licenc kezelése" Style="{StaticResource UtilityButton}"/>
            <TextBlock Name="ActiveProfileText" Text="Aktív profil: Egyéni" Foreground="{DynamicResource AccentTextBrush}" FontWeight="SemiBold" FontSize="12" Margin="4,0,0,10"/>
            <Button Name="AboutButton" Content="ⓘ  A SoundLiftről és Discord" Style="{StaticResource UtilityButton}"/>
            <Button Name="PrivacyButton" Content="◈  Adatvédelem" Style="{StaticResource UtilityButton}"/>
            <Button Name="ApplyButton" Content="BEÁLLÍTÁSOK ALKALMAZÁSA" Style="{StaticResource PrimaryButton}" FontSize="13" Padding="10,13"/>
          </StackPanel>
        </Grid>
      </Border>

      <ScrollViewer Grid.Column="2" VerticalScrollBarVisibility="Hidden" HorizontalScrollBarVisibility="Disabled" PanningMode="VerticalOnly">
        <StackPanel>
          <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="22,17" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}" Margin="0,0,0,14">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="26"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <StackPanel>
                <DockPanel><TextBlock Text="Hangerő erősítése" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource PrimaryTextBrush}"/><TextBlock Name="VolumeValue" Text="100%" FontSize="17" FontWeight="Bold" Foreground="{DynamicResource AccentTextBrush}" HorizontalAlignment="Right"/></DockPanel>
                <Slider Name="VolumeSlider" Minimum="0" Maximum="300" Value="100" TickFrequency="5" IsSnapToTickEnabled="True"/>
                <TextBlock Text="0% = némítás  •  100% = eredeti hangerő  •  maximum 300%" FontSize="11" Foreground="{DynamicResource MutedTextBrush}"/>
              </StackPanel>
              <StackPanel Grid.Column="2">
                <DockPanel><TextBlock Text="Mélyhangkiemelés" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource PrimaryTextBrush}"/><TextBlock Name="BassValue" Text="6 dB" FontSize="17" FontWeight="Bold" Foreground="{DynamicResource AccentTextBrush}" HorizontalAlignment="Right"/></DockPanel>
                <Slider Name="BassSlider" Minimum="0" Maximum="24" Value="6" TickFrequency="1" IsSnapToTickEnabled="True"/>
                <TextBlock Text="A basszus ereje 0 és 24 dB között" FontSize="11" Foreground="{DynamicResource MutedTextBrush}"/>
              </StackPanel>
            </Grid>
          </Border>

          <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="22,17" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}" Margin="0,0,0,14">
            <Grid>
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <DockPanel>
                <TextBlock Text="Basszus karaktere" FontSize="15" FontWeight="SemiBold" Foreground="{DynamicResource PrimaryTextBrush}"/>
                <TextBlock Name="FrequencyValue" Text="75 Hz" FontSize="17" FontWeight="Bold" Foreground="{DynamicResource AccentTextBrush}" HorizontalAlignment="Right"/>
              </DockPanel>
              <Slider Name="FrequencySlider" Grid.Row="1" Minimum="40" Maximum="160" Value="75" TickFrequency="5" IsSnapToTickEnabled="True"/>
            </Grid>
          </Border>

          <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="22,15" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}" Margin="0,0,0,14">
            <Grid>
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <DockPanel Margin="0,0,0,10">
                <TextBlock Text="ÉLŐ HANGMÉRŐ" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}"/>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                  <TextBlock Name="LiveBoostText" Text="Erősítés: 0,0 dB" Foreground="{DynamicResource MutedTextBrush}" FontSize="11" Margin="0,0,14,0"/>
                  <TextBlock Name="LiveClipText" Text="NINCS JEL" Foreground="{DynamicResource MutedTextBrush}" FontSize="11" FontWeight="Bold"/>
                </StackPanel>
              </DockPanel>
              <Grid Grid.Row="1" Margin="0,0,0,7">
                <Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/><ColumnDefinition Width="48"/></Grid.ColumnDefinitions>
                <TextBlock Text="B" ToolTip="Bal csatorna" Foreground="{DynamicResource MutedTextBrush}" VerticalAlignment="Center"/>
                <ProgressBar Name="LeftPeakMeter" Grid.Column="1" Height="9" Minimum="0" Maximum="100" Value="0" Foreground="{DynamicResource AccentTextBrush}" Background="{DynamicResource ControlBrush}" BorderThickness="0"/>
                <TextBlock Name="LeftPeakText" Grid.Column="2" Text="0%" Foreground="{DynamicResource SecondaryTextBrush}" HorizontalAlignment="Right" VerticalAlignment="Center" FontSize="11"/>
              </Grid>
              <Grid Grid.Row="2">
                <Grid.ColumnDefinitions><ColumnDefinition Width="18"/><ColumnDefinition Width="*"/><ColumnDefinition Width="48"/></Grid.ColumnDefinitions>
                <TextBlock Text="J" ToolTip="Jobb csatorna" Foreground="{DynamicResource MutedTextBrush}" VerticalAlignment="Center"/>
                <ProgressBar Name="RightPeakMeter" Grid.Column="1" Height="9" Minimum="0" Maximum="100" Value="0" Foreground="{DynamicResource AccentTextBrush}" Background="{DynamicResource ControlBrush}" BorderThickness="0"/>
                <TextBlock Name="RightPeakText" Grid.Column="2" Text="0%" Foreground="{DynamicResource SecondaryTextBrush}" HorizontalAlignment="Right" VerticalAlignment="Center" FontSize="11"/>
              </Grid>
            </Grid>
          </Border>

          <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="22,15" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}" Margin="0,0,0,14">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <StackPanel>
                <TextBlock Text="VÉDELEM ÉS AUTOMATIZÁLÁS" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}" Margin="0,0,0,8"/>
                <WrapPanel>
                  <CheckBox Name="SafetyCheck" Content="Torzításvédelem" IsChecked="True"/>
                  <CheckBox Name="AutoProfileCheck" Visibility="Collapsed" IsChecked="False"/>
                  <CheckBox Name="InstantCheck" Content="Módosítások azonnali alkalmazása"/>
                  <CheckBox Name="StartupCheck" Content="Automatikus indítás a Windowssal"/>
                  <CheckBox Name="DoNotDisturbCheck" Content="Ne zavarjanak mód" ToolTip="Játék közben elrejti a nem fontos felugró értesítéseket."/>
                  <CheckBox Name="NightModeCheck" Visibility="Collapsed" IsChecked="False"/>
                  <CheckBox Name="OverlayCheck" Visibility="Collapsed" IsChecked="False"/>
                  <CheckBox Name="DiscordPresenceCheck" Visibility="Collapsed" IsChecked="False"/>
                </WrapPanel>
              </StackPanel>
              <Border Grid.Column="1" Background="#12291F" CornerRadius="9" Padding="12,7" VerticalAlignment="Center">
                <TextBlock Name="ClipText" Text="VÉDVE" Foreground="#4ADE80" FontWeight="Bold" FontSize="11"/>
              </Border>
            </Grid>
          </Border>

          <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="22,15" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}" Margin="0,0,0,14">
            <StackPanel>
              <DockPanel Margin="0,0,0,10">
                <TextBlock Text="10 SÁVOS HANGSZÍNSZABÁLYZÓ" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}"/>
                <TextBlock Text="-12 dB  •  +12 dB" HorizontalAlignment="Right" Foreground="{DynamicResource MutedTextBrush}" FontSize="11"/>
              </DockPanel>
              <Border Background="{DynamicResource SurfaceAltBrush}" CornerRadius="12" Padding="12">
                <UniformGrid Name="EqPanel" Rows="1" Columns="10"/>
              </Border>
            </StackPanel>
          </Border>

          <Border Background="{DynamicResource SurfaceBrush}" CornerRadius="18" Padding="20,17" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1" Effect="{StaticResource CardShadow}">
            <Grid>
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <TextBlock Text="ESZKÖZÖK ÉS KARBANTARTÁS" FontSize="11" FontWeight="Bold" Foreground="{DynamicResource SectionTextBrush}" Margin="2,0,0,12"/>
              <Grid Grid.Row="1">
                <Grid.ColumnDefinitions><ColumnDefinition Width="1*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="1*"/><ColumnDefinition Width="12"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
                <Border Background="{DynamicResource SurfaceAltBrush}" CornerRadius="13" Padding="14,12" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="PROFILOK" Foreground="{DynamicResource SectionTextBrush}" FontSize="10" FontWeight="Bold" Margin="2,0,0,3"/>
                    <TextBlock Text="Mentés, betöltés és átvitel" Foreground="{DynamicResource MutedTextBrush}" FontSize="10" Margin="2,0,0,10"/>
                    <Button Name="ProfileManagerButton" Content="☰  Profilkezelés" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="SaveButton" Visibility="Collapsed"/>
                    <Button Name="LoadButton" Visibility="Collapsed"/>
                    <Button Name="ExportButton" Visibility="Collapsed"/>
                    <Button Name="ImportButton" Visibility="Collapsed"/>
                    <Button Name="UndoButton" Content="↶  Előző beállítás visszaállítása" Style="{StaticResource UtilityButton}" Margin="0"/>
                  </StackPanel>
                </Border>
                <Border Grid.Column="2" Background="{DynamicResource SurfaceAltBrush}" CornerRadius="13" Padding="14,12" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="HANGRENDSZER" Foreground="{DynamicResource SectionTextBrush}" FontSize="10" FontWeight="Bold" Margin="2,0,0,3"/>
                    <TextBlock Text="Equalizer APO beállítása és ellenőrzése" Foreground="{DynamicResource MutedTextBrush}" FontSize="10" Margin="2,0,0,10"/>
                    <Button Name="TestButton" Content="◉  Basszus tesztelése (60 Hz)" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="DeviceButton" Content="▣  Hangeszközök beállítása" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="AppVolumeButton" Content="▥  Alkalmazásonkénti hangerő" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="MicrophoneButton" Content="◉  Mikrofonjavítás" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="DiagnosticsButton" Content="✓  Rendszer ellenőrzése" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="RepairApoButton" Content="⟳  APO-kapcsolat javítása" Style="{StaticResource UtilityButton}" Margin="0"/>
                  </StackPanel>
                </Border>
                <Border Grid.Column="4" Background="{DynamicResource SurfaceAltBrush}" CornerRadius="13" Padding="14,12" BorderBrush="{DynamicResource BorderBrush}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="TÁMOGATÁS ÉS FRISSÍTÉS" Foreground="{DynamicResource SectionTextBrush}" FontSize="10" FontWeight="Bold" Margin="2,0,0,3"/>
                    <TextBlock Text="Segítség és alkalmazásverzió" Foreground="{DynamicResource MutedTextBrush}" FontSize="10" Margin="2,0,0,10"/>
                    <Button Name="ReportProblemButton" Content="⚑  Hibajelentés küldése" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="UpdateButton" Content="↻  Frissítés keresése" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="ChangelogButton" Content="≡  Frissítési előzmények" Style="{StaticResource UtilityButton}" Margin="0,0,0,8"/>
                    <Button Name="HotkeyButton" Content="⌨  Billentyűparancsok" Style="{StaticResource UtilityButton}" Margin="0,0,0,8" ToolTip="A globális profilváltó és gyors némító billentyűk szerkesztése."/>
                    <Button Name="StatisticsButton" Visibility="Collapsed"/>
                    <Button Name="DeveloperConsoleButton" Content="⌘  Fejlesztői konzol" Style="{StaticResource UtilityButton}" Margin="0,0,0,8" Visibility="Collapsed"/>
                    <Button Name="OwnerModeButton" Visibility="Collapsed"/>
                    <Button Name="RollbackButton" Visibility="Collapsed"/>
                  </StackPanel>
                </Border>
              </Grid>
              <Border Grid.Row="2" Background="#150B0D" CornerRadius="12" Padding="14,10" BorderBrush="#352026" BorderThickness="1" Margin="0,12,0,0">
                <DockPanel>
                  <StackPanel VerticalAlignment="Center">
                    <TextBlock Text="HANGFELDOLGOZÁS" Foreground="#A66B74" FontSize="10" FontWeight="Bold"/>
                    <TextBlock Text="Az Equalizer APO eredeti hangjára vált vissza." Foreground="#6F7888" FontSize="11" Margin="0,3,0,0"/>
                  </StackPanel>
                  <Button Name="BypassButton" Content="⛨  Biztonságos mód" Style="{StaticResource DangerButton}" HorizontalAlignment="Right" Margin="16,0,0,0" ToolTip="A SoundLift hanghatásainak azonnali kikapcsolása és az eredeti hang visszaállítása"/>
                </DockPanel>
              </Border>
            </Grid>
          </Border>
        </StackPanel>
      </ScrollViewer>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)
$window.Dispatcher.Add_UnhandledException({
    param($sender, $eventArgs)
    try {
        Write-SoundLiftLog -Category crash -EventName 'unhandled_runtime_error' -Severity critical -Data @{
            exception_type=$eventArgs.Exception.GetType().FullName
            message=$eventArgs.Exception.Message
            script_stack=$eventArgs.Exception.StackTrace
        }
        [void](Send-SoundLiftPendingLogs)
        Show-SoundLiftMessage "A SoundLift váratlan hibát észlelt, ezért biztonságosan bezárul.`nA részletes napló itt található:`n$script:logRoot" 'SoundLift – hiba' 'OK' 'Error' $window | Out-Null
    } catch { }
    $eventArgs.Handled = $true
    $script:reallyExit = $true
    $window.Close()
}.GetNewClosure())
$appIconPath = Join-Path $script:appDirectory 'SoundLift.ico'
if (Test-Path $appIconPath) {
    try { $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$appIconPath) } catch { }
}
# Create the notification-area icon as soon as the main window exists. It is
# kept in script scope for the entire process lifetime, independently of the
# main window's visibility.
$script:reallyExit = $false
$script:trayIcon = New-Object Windows.Forms.NotifyIcon
$script:trayIcon.Icon = if (Test-Path $appIconPath) { New-Object Drawing.Icon($appIconPath) } else { [Drawing.SystemIcons]::Application }
$script:trayIcon.Text = 'SoundLift V1.6.0'
$script:trayIcon.Visible = $true
$names = @('StatusBorder','StatusText','DeviceText','ProfilePanel','ProfileOrderButton','VolumeValue','BassValue','FrequencyValue','VolumeSlider','BassSlider','FrequencySlider','SafetyCheck','MusicButton','GameButton','CombatButton','R6Button','DiscordButton','MovieButton','HeavyButton','ResetButton','CustomFeaturesTitle','ExtraBassProButton','VoiceBoostButton','CustomPresetXButton','ApplyButton','EqPanel','AutoProfileCheck','InstantCheck','StartupCheck','DoNotDisturbCheck','NightModeCheck','OverlayCheck','DiscordPresenceCheck','ClipText','LeftPeakMeter','RightPeakMeter','LeftPeakText','RightPeakText','LiveBoostText','LiveClipText','ProfileManagerButton','SaveButton','LoadButton','ExportButton','ImportButton','UndoButton','BypassButton','TestButton','DeviceButton','AppVolumeButton','MicrophoneButton','DiagnosticsButton','RepairApoButton','ReportProblemButton','UpdateButton','RollbackButton','OwnerModeButton','ChangelogButton','HotkeyButton','StatisticsButton','DeveloperConsoleButton','AboutButton','PrivacyButton','ActiveProfileText','ThemeCombo','VersionText','SupportIdText','CopySupportIdButton','LicenseStatusText','LicenseButton')
foreach ($name in $names) { Set-Variable -Name $name -Value $window.FindName($name) }
$VolumeSlider.ToolTip = 'A teljes hangerő erősítése 0 és 300% között.'
$BassSlider.ToolTip = 'A mélyhangok kiemelése. Nagy értéknél használd a torzításvédelmet.'
$FrequencySlider.ToolTip = 'A basszuskiemelés középfrekvenciája.'
$SafetyCheck.ToolTip = 'Automatikusan csökkenti a túlvezérlés és recsegés veszélyét.'
$AutoProfileCheck.ToolTip = 'Futó alkalmazás alapján automatikusan kiválasztja a megfelelő profilt.'
$InstantCheck.ToolTip = 'A csúszkák módosítását rövid késleltetéssel azonnal alkalmazza.'
$VersionText.Text = "Telepített verzió: $script:appVersion"
$SupportIdText.Text = "Támogatási ID: $(Get-SoundLiftSupportId)"
$CopySupportIdButton.Add_Click({
    try {
        [Windows.Forms.Clipboard]::SetText((Get-SoundLiftSupportId))
        $StatusText.Text = 'Támogatási ID a vágólapra másolva'
    } catch { Show-SoundLiftMessage 'A támogatási ID most nem másolható a vágólapra.' 'SoundLift' 'OK' 'Warning' $window | Out-Null }
})

$script:eqBands = @(31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)
$script:eqSliders = @()
$script:eqValueLabels = @()
$script:eqBandLabels = @()
for ($i = 0; $i -lt $script:eqBands.Count; $i++) {
    $column = New-Object Windows.Controls.StackPanel
    $column.HorizontalAlignment = 'Center'
    $bandLabel = New-Object Windows.Controls.TextBlock
    $bandLabel.Text = if ($script:eqBands[$i] -ge 1000) { "$($script:eqBands[$i] / 1000)k" } else { "$($script:eqBands[$i])" }
    $bandLabel.HorizontalAlignment = 'Center'; $bandLabel.Foreground = '#AAB2C0'
    $slider = New-Object Windows.Controls.Slider
    $slider.Minimum = -12; $slider.Maximum = 12; $slider.Value = 0; $slider.TickFrequency = 1; $slider.IsSnapToTickEnabled = $true
    $slider.Style = $window.FindResource('VerticalEqSlider')
    $valueLabel = New-Object Windows.Controls.TextBlock
    $valueLabel.Text = '0'; $valueLabel.HorizontalAlignment = 'Center'; $valueLabel.Foreground = '#FF4057'
    [void]$column.Children.Add($bandLabel); [void]$column.Children.Add($slider); [void]$column.Children.Add($valueLabel)
    [void]$EqPanel.Children.Add($column)
    $script:eqSliders += $slider; $script:eqValueLabels += $valueLabel
    $script:eqBandLabels += $bandLabel
    $index = $i
    $slider.Add_ValueChanged({ $script:eqValueLabels[$index].Text = ([int]$script:eqSliders[$index].Value).ToString() }.GetNewClosure())
}

function Set-AppTheme([string]$themeName) {
    $theme = Get-SoundLiftThemePalette $themeName

    $accentColor = [Windows.Media.ColorConverter]::ConvertFromString($theme.Accent)
    $accentDarkColor = [Windows.Media.ColorConverter]::ConvertFromString($theme.AccentDark)
    $pageColor = [Windows.Media.ColorConverter]::ConvertFromString($theme.Page)
    $baseColor = [Windows.Media.ColorConverter]::ConvertFromString($(if ($theme.Base) { $theme.Base } else { '#070707' }))

    $accentGradient = [Windows.Media.LinearGradientBrush]::new()
    $accentGradient.StartPoint = [Windows.Point]::new(0, 0)
    $accentGradient.EndPoint = [Windows.Point]::new(1, 1)
    $accentGradient.GradientStops.Add([Windows.Media.GradientStop]::new($accentColor, 0))
    $accentGradient.GradientStops.Add([Windows.Media.GradientStop]::new($accentDarkColor, 1))
    $window.Resources['AccentGradient'] = $accentGradient

    $pageGradient = [Windows.Media.LinearGradientBrush]::new()
    $pageGradient.StartPoint = [Windows.Point]::new(0, 0)
    $pageGradient.EndPoint = [Windows.Point]::new(1, 1)
    $pageGradient.GradientStops.Add([Windows.Media.GradientStop]::new($baseColor, 0))
    $pageGradient.GradientStops.Add([Windows.Media.GradientStop]::new($pageColor, 0.55))
    $pageGradient.GradientStops.Add([Windows.Media.GradientStop]::new($baseColor, 1))
    $window.Resources['PageGradient'] = $pageGradient

    $window.Resources['AccentTextBrush'] = [Windows.Media.SolidColorBrush]::new($accentColor)
    $window.Resources['HoverBrush'] = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($theme.Hover))
    $palette = $theme
    foreach($entry in $palette.GetEnumerator()) { $window.Resources[($entry.Key + 'Brush')] = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString([string]$entry.Value)) }
    foreach ($label in $script:eqValueLabels) { $label.Foreground = $window.Resources['AccentTextBrush'] }
    foreach ($label in $script:eqBandLabels) { $label.Foreground = $window.Resources['MutedTextBrush'] }
    $window.Foreground = $window.Resources['PrimaryTextBrush']
    foreach ($control in @($MusicButton,$GameButton,$CombatButton,$R6Button,$DiscordButton,$MovieButton,$HeavyButton,$ResetButton,$ExtraBassProButton,$VoiceBoostButton,$CustomPresetXButton,$ProfileOrderButton,$CopySupportIdButton,$LicenseButton,$AboutButton,$PrivacyButton,$SaveButton,$LoadButton,$ExportButton,$ImportButton,$UndoButton,$TestButton,$DeviceButton,$AppVolumeButton,$MicrophoneButton,$DiagnosticsButton,$RepairApoButton,$ReportProblemButton,$UpdateButton,$RollbackButton,$OwnerModeButton,$ChangelogButton,$HotkeyButton,$StatisticsButton,$DeveloperConsoleButton)) {
        if ($control) { $control.Foreground = $window.Resources['PrimaryTextBrush'] }
    }
    foreach ($checkBox in @($SafetyCheck,$AutoProfileCheck,$InstantCheck,$StartupCheck,$DoNotDisturbCheck,$NightModeCheck,$OverlayCheck,$DiscordPresenceCheck)) { if ($checkBox) { $checkBox.Foreground = $window.Resources['SecondaryTextBrush'] } }
    $ThemeCombo.Foreground = $window.Resources['PrimaryTextBrush']
    $VersionText.Foreground = $window.Resources['MutedTextBrush']; $SupportIdText.Foreground = $window.Resources['MutedTextBrush']; $LicenseStatusText.Foreground = $window.Resources['MutedTextBrush']
    $ApplyButton.Foreground = $window.Resources['AccentContrastBrush']
    $script:themeName = $themeName
}

$script:themeNames = @(
    'Fekete és piros', 'Fekete és kék', 'Grafit és zöld',
    'Fekete és lila', 'Éjkék és türkiz', 'Grafit és narancs',
    'Fekete és arany', 'OLED fekete'
)
foreach ($themeName in $script:themeNames) { [void]$ThemeCombo.Items.Add($themeName) }
$ThemeCombo.SelectedItem = $script:themeName
$ThemeCombo.Add_SelectionChanged({
    if ($ThemeCombo.SelectedItem) { Set-AppTheme ([string]$ThemeCombo.SelectedItem) }
})
Set-AppTheme $script:themeName

function Set-EqValues([double[]]$values) {
    for ($i = 0; $i -lt $script:eqSliders.Count; $i++) { $script:eqSliders[$i].Value = $values[$i] }
}

function Get-SoundLiftProfileDisplayName([string]$profileId) {
    $result = switch ($profileId) {
        'Music' { 'Zene' }
        'FiveM RP' { 'FiveM RP' }
        'FiveM Combat' { 'FiveM PvP' }
        'R6' { 'Rainbow Six Siege' }
        'Movie' { 'Film' }
        'Heavy' { 'Erőteljes basszus' }
        'Custom' { 'Egyéni' }
        'Extra Bass Pro' { 'Extra mélyhang Pro' }
        'Voice Boost' { 'Beszédkiemelés' }
        'Custom Preset X' { 'Egyéni profil X' }
        default { if ([string]::IsNullOrWhiteSpace($profileId)) { 'Egyéni' } else { $profileId } }
    }
    return [string]$result
}

function Show-ProfileOverlay([string]$profileName) {
    if (-not $script:profileOverlayEnabled -or $script:doNotDisturb) { return }
    try {
        $overlay = [Windows.Window]::new()
        $overlay.Width=330; $overlay.Height=92; $overlay.WindowStyle='None'; $overlay.ResizeMode='NoResize'; $overlay.ShowInTaskbar=$false
        $overlay.Topmost=$true; $overlay.ShowActivated=$false; $overlay.Focusable=$false; $overlay.IsHitTestVisible=$false; $overlay.AllowsTransparency=$true; $overlay.Background=[Windows.Media.Brushes]::Transparent
        $work=[Windows.SystemParameters]::WorkArea; $overlay.Left=$work.Right-$overlay.Width-20; $overlay.Top=$work.Top+20
        $card=[Windows.Controls.Border]::new(); $card.Background='#EE111113'; $card.BorderBrush=$window.Resources['AccentTextBrush']; $card.BorderThickness=[Windows.Thickness]::new(1); $card.CornerRadius=[Windows.CornerRadius]::new(14); $card.Padding=[Windows.Thickness]::new(18,13,18,13)
        $panel=[Windows.Controls.StackPanel]::new(); $title=[Windows.Controls.TextBlock]::new(); $title.Text='SOUNDLIFT PROFIL'; $title.FontSize=10; $title.FontWeight='Bold'; $title.Foreground=$window.Resources['AccentTextBrush']
        $name=[Windows.Controls.TextBlock]::new(); $name.Text=$profileName; $name.FontSize=20; $name.FontWeight='SemiBold'; $name.Foreground='#F8FAFC'; $name.Margin=[Windows.Thickness]::new(0,3,0,0)
        [void]$panel.Children.Add($title); [void]$panel.Children.Add($name); $card.Child=$panel; $overlay.Content=$card
        $timer=[Windows.Threading.DispatcherTimer]::new(); $timer.Interval=[TimeSpan]::FromMilliseconds(1700); $timer.Add_Tick({$timer.Stop();$overlay.Close()}.GetNewClosure())
        $overlay.Add_ContentRendered({$timer.Start()}.GetNewClosure()); $overlay.Show()
    } catch { }
}

function Add-ProfileStatistic([string]$profileId) {
    if (-not $script:statistics) { return }
    $script:statistics.profileSwitches = [int64]$script:statistics.profileSwitches + 1
    if (-not $script:statistics.profiles) { $script:statistics | Add-Member -NotePropertyName profiles -NotePropertyValue ([PSCustomObject]@{}) -Force }
    $property=$script:statistics.profiles.PSObject.Properties[$profileId]
    if ($property) { $property.Value=[int64]$property.Value+1 } else { $script:statistics.profiles | Add-Member -NotePropertyName $profileId -NotePropertyValue ([int64]1) }
}

function Update-Labels {
    $VolumeValue.Text = "$([int]$VolumeSlider.Value)%"
    $BassValue.Text = "$([int]$BassSlider.Value) dB"
    $FrequencyValue.Text = "$([int]$FrequencySlider.Value) Hz"
    $roughVolumeDb = if ([double]$VolumeSlider.Value -le 0) { -100.0 } else { 20.0 * [Math]::Log10([double]$VolumeSlider.Value / 100.0) }
    $roughPeak = $roughVolumeDb + ([double]$BassSlider.Value * 0.55)
    if ($SafetyCheck.IsChecked) {
        $ClipText.Text = 'VÉDVE'; $ClipText.Foreground = '#4ADE80'
    } elseif ($roughPeak -gt 6) {
        $ClipText.Text = 'TORZÍTÁSVESZÉLY'; $ClipText.Foreground = '#FB7185'
    } else {
        $ClipText.Text = 'VÉDELEM NÉLKÜL'; $ClipText.Foreground = '#FBBF24'
    }
}

function Set-Profile([int]$volume, [int]$bass, [int]$frequency, [bool]$safe = $true) {
    $VolumeSlider.Value = $volume; $BassSlider.Value = $bass; $FrequencySlider.Value = $frequency
    $displayName = Get-SoundLiftProfileDisplayName $script:activeProfile
    $SafetyCheck.IsChecked = $safe; $ActiveProfileText.Text = "Aktív profil: $displayName"; Update-Labels
    Add-ProfileStatistic $script:activeProfile
    Show-ProfileOverlay $displayName
}

$VolumeSlider.Add_ValueChanged({ Update-Labels })
$BassSlider.Add_ValueChanged({ Update-Labels })
$FrequencySlider.Add_ValueChanged({ Update-Labels })
$script:activeProfile = 'Custom'
$MusicButton.Add_Click({ $script:activeProfile = 'Music'; Set-Profile 170 5 72 $true; Set-EqValues @(2,2,1,-1,-1,0,1,2,1,1) })
$GameButton.Add_Click({ $script:activeProfile = 'FiveM RP'; Set-Profile 140 2 80 $true; Set-EqValues @(-2,-1,0,-2,-2,0,2,3,1,0) })
$CombatButton.Add_Click({ $script:activeProfile = 'FiveM Combat'; Set-Profile 140 1 85 $true; Set-EqValues @(-3,-2,-1,-2,-1,1,3,3,2,0) })
$R6Button.Add_Click({ $script:activeProfile = 'R6'; Set-Profile 140 0 90 $true; Set-EqValues @(-4,-3,-2,-2,-1,1,3,4,2,0) })
$DiscordButton.Add_Click({ $script:activeProfile = 'Discord'; Set-Profile 130 0 80 $true; Set-EqValues @(-3,-2,-1,-2,-1,1,3,2,0,-1) })
$MovieButton.Add_Click({ $script:activeProfile = 'Movie'; Set-Profile 145 5 65 $true; Set-EqValues @(1,1,0,-1,-2,0,2,2,1,1) })
$HeavyButton.Add_Click({ $script:activeProfile = 'Heavy'; Set-Profile 175 11 58 $true; Set-EqValues @(2,2,1,-2,-2,-1,1,2,1,0) })
$ResetButton.Add_Click({ $script:activeProfile = 'Custom'; Set-Profile 100 0 75 $true; Set-EqValues @(0,0,0,0,0,0,0,0,0,0) })
$ExtraBassProButton.Add_Click({ $script:activeProfile='Extra Bass Pro'; Set-Profile 185 14 55 $true; Set-EqValues @(5,5,3,0,-2,-1,0,1,0,-1) })
$VoiceBoostButton.Add_Click({ $script:activeProfile='Voice Boost'; Set-Profile 145 0 105 $true; Set-EqValues @(-4,-3,-2,0,2,4,5,3,0,-2) })
$CustomPresetXButton.Add_Click({ $script:activeProfile='Custom Preset X'; Set-Profile 155 7 68 $true; Set-EqValues @(3,2,1,-1,-2,1,3,2,1,0) })

function Get-ProfileButtonMap {
    return @{'Music'=$MusicButton;'FiveM RP'=$GameButton;'FiveM Combat'=$CombatButton;'R6'=$R6Button;'Discord'=$DiscordButton;'Movie'=$MovieButton;'Heavy'=$HeavyButton;'Custom'=$ResetButton}
}

function Get-ProfileDisplayName([string]$profileId) {
    return @{'Music'='Zene';'FiveM RP'='FiveM RP';'FiveM Combat'='FiveM PvP';'R6'='Rainbow Six Siege';'Discord'='Discord';'Movie'='Film';'Heavy'='Erőteljes basszus';'Custom'='Alapbeállítások'}[$profileId]
}

function Apply-ProfileLayout {
    $map=Get-ProfileButtonMap
    $valid=@('Music','FiveM RP','FiveM Combat','R6','Discord','Movie','Heavy','Custom')
    $ordered=@('Music') + @($script:profileOrder | Where-Object { $_ -ne 'Music' -and $_ -in $valid })
    $ordered += @($valid | Where-Object { $_ -notin $ordered })
    $script:profileOrder=@($ordered)
    foreach($id in $valid){[void]$ProfilePanel.Children.Remove($map[$id])}
    for($i=0;$i -lt $script:profileOrder.Count;$i++){
        $id=$script:profileOrder[$i];$button=$map[$id]
        $button.Visibility=if($id -in $script:hiddenProfiles -and $id -ne 'Music'){'Collapsed'}else{'Visible'}
        $ProfilePanel.Children.Insert($i,$button)
    }
}

function Show-ProfileOrderEditor {
    $dialog=[Windows.Window]::new();$dialog.Title='SoundLift – Profilok rendezése';$dialog.Width=520;$dialog.Height=620;$dialog.ResizeMode='NoResize';$dialog.WindowStartupLocation='CenterOwner';$dialog.Owner=$window;Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.Grid]::new();$root.Margin=[Windows.Thickness]::new(24);$root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new());$actions=[Windows.Controls.RowDefinition]::new();$actions.Height=[Windows.GridLength]::Auto;$root.RowDefinitions.Add($actions)
    $panel=[Windows.Controls.StackPanel]::new();$title=[Windows.Controls.TextBlock]::new();$title.Text='Profilok rendezése';$title.FontSize=23;$title.FontWeight='Bold';$title.Foreground=$window.Resources['AccentTextBrush'];[void]$panel.Children.Add($title)
    $hint=[Windows.Controls.TextBlock]::new();$hint.Text='A Zene mindig legfelül marad. A többi profilt fel-le mozgathatod vagy elrejtheted.';$hint.TextWrapping='Wrap';$hint.Foreground='#94A3B8';$hint.Margin=[Windows.Thickness]::new(0,5,0,14);[void]$panel.Children.Add($hint)
    $list=[Windows.Controls.ListBox]::new();$list.Height=250;$list.Background='#111113';$list.Foreground='#F8FAFC';$list.BorderBrush='#29292E';$list.Padding=[Windows.Thickness]::new(6);[void]$panel.Children.Add($list)
    $workingOrder=[Collections.ArrayList]@($script:profileOrder);$workingHidden=[Collections.ArrayList]@($script:hiddenProfiles)
    $refresh={ $selected=$list.SelectedIndex;$list.Items.Clear();foreach($id in $workingOrder){$suffix=if($id -in $workingHidden){'  (elrejtve)'}else{''};[void]$list.Items.Add("$(Get-ProfileDisplayName $id)$suffix")};if($selected -ge 0 -and $selected -lt $list.Items.Count){$list.SelectedIndex=$selected} }.GetNewClosure(); & $refresh
    $tools=[Windows.Controls.StackPanel]::new();$tools.Orientation='Horizontal';$tools.HorizontalAlignment='Center';$tools.Margin=[Windows.Thickness]::new(0,14,0,0)
    $up=[Windows.Controls.Button]::new();$up.Content='↑  Fel';$up.Style=$window.Resources['UtilityButton'];$up.Width=90;$up.Height=40
    $down=[Windows.Controls.Button]::new();$down.Content='↓  Le';$down.Style=$window.Resources['UtilityButton'];$down.Width=90;$down.Height=40
    $toggle=[Windows.Controls.Button]::new();$toggle.Content='Elrejtés / mutatás';$toggle.Style=$window.Resources['UtilityButton'];$toggle.Width=170;$toggle.Height=40
    $up.Add_Click({$i=$list.SelectedIndex;if($i -gt 1){$item=$workingOrder[$i];$workingOrder.RemoveAt($i);$workingOrder.Insert($i-1,$item);$list.SelectedIndex=$i-1;&$refresh}}.GetNewClosure())
    $down.Add_Click({$i=$list.SelectedIndex;if($i -ge 1 -and $i -lt $workingOrder.Count-1){$item=$workingOrder[$i];$workingOrder.RemoveAt($i);$workingOrder.Insert($i+1,$item);$list.SelectedIndex=$i+1;&$refresh}}.GetNewClosure())
    $toggle.Add_Click({$i=$list.SelectedIndex;if($i -lt 1){return};$id=$workingOrder[$i];if($id -in $workingHidden){$workingHidden.Remove($id)}else{[void]$workingHidden.Add($id)};&$refresh}.GetNewClosure())
    [void]$tools.Children.Add($up);[void]$tools.Children.Add($down);[void]$tools.Children.Add($toggle);[void]$panel.Children.Add($tools)
    $bottom=[Windows.Controls.StackPanel]::new();$bottom.Orientation='Horizontal';$bottom.HorizontalAlignment='Right';$bottom.Margin=[Windows.Thickness]::new(0,16,0,0)
    $cancel=[Windows.Controls.Button]::new();$cancel.Content='Mégse';$cancel.Style=$window.Resources['UtilityButton'];$cancel.Width=100;$cancel.Add_Click({$dialog.Close()}.GetNewClosure())
    $save=[Windows.Controls.Button]::new();$save.Content='Mentés';$save.Style=$window.Resources['PrimaryButton'];$save.Width=120;$save.Add_Click({$script:profileOrder=@($workingOrder);$script:hiddenProfiles=@($workingHidden);Apply-ProfileLayout;(Get-AppState)|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $settingsPath -Encoding UTF8;$dialog.Close();$StatusText.Text='A profilsorrend mentve'}.GetNewClosure())
    [void]$bottom.Children.Add($cancel);[void]$bottom.Children.Add($save);[Windows.Controls.Grid]::SetRow($bottom,1);[void]$root.Children.Add($panel);[void]$root.Children.Add($bottom);$dialog.Content=$root;$dialog.ShowDialog()|Out-Null
}
$ProfileOrderButton.Add_Click({Show-ProfileOrderEditor})

$apoDirectory = Get-ApoConfigDirectory
if ($apoDirectory) {
    $StatusText.Text = "Készen áll • Az Equalizer APO megfelelően csatlakozik"
    $StatusBorder.Background = '#143126'
} else {
    $StatusText.Text = "Beavatkozás szükséges • Az Equalizer APO nem található; lásd a TELEPÍTÉS.txt fájlt"
    $StatusBorder.Background = '#3A2812'
}

function Read-TextWithRetry([string]$path) {
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try { return [IO.File]::ReadAllText($path) }
        catch [IO.IOException] { if ($attempt -eq 20) { throw }; [Threading.Thread]::Sleep(100) }
    }
}

function Write-LinesWithRetry([string]$path, [string[]]$lines) {
    $encoding = New-Object Text.UTF8Encoding($false)
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try { [IO.File]::WriteAllLines($path, $lines, $encoding); return }
        catch [IO.IOException] { if ($attempt -eq 20) { throw }; [Threading.Thread]::Sleep(100) }
    }
}

function Write-TextWithRetry([string]$path, [string]$value) {
    $encoding = New-Object Text.UTF8Encoding($false)
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try { [IO.File]::WriteAllText($path, $value, $encoding); return }
        catch [IO.IOException] { if ($attempt -eq 20) { throw }; [Threading.Thread]::Sleep(100) }
    }
}

$script:applyBusy = $false
$ApplyButton.Add_Click({
    if ($script:applyBusy) { return }
    $script:applyBusy = $true
    try {
        $apoDirectory = Get-ApoConfigDirectory
        if (-not $apoDirectory) {
            Show-SoundLiftMessage "Előbb telepítsd az Equalizer APO-t, majd indítsd újra az appot.`n`nA pontos lépéseket a TELEPÍTÉS.txt tartalmazza." 'SoundLift' 'OK' 'Warning' $window | Out-Null
            return
        }
        if (-not (Test-Administrator)) {
            $answer = Show-SoundLiftMessage 'A beállítás mentéséhez rendszergazdai jogosultság kell. Újraindítsam az appot rendszergazdaként?' 'SoundLift' 'YesNo' 'Question' $window
            if ($answer -eq 'Yes') {
                Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
                $window.Close()
            }
            return
        }

        $volumePercent = [double]$VolumeSlider.Value
        $bassDb = [double]$BassSlider.Value
        $frequency = [int]$FrequencySlider.Value
        $volumeDb = if ($volumePercent -le 0) { -100.0 } else { 20.0 * [Math]::Log10($volumePercent / 100.0) }
        $maxEqGain = 0.0
        foreach ($eqSlider in $script:eqSliders) { if ([double]$eqSlider.Value -gt $maxEqGain) { $maxEqGain = [double]$eqSlider.Value } }
        if ((-not $SafetyCheck.IsChecked) -and ($volumePercent -gt 200 -or $bassDb -gt 15)) {
            $warning = Show-SoundLiftMessage 'Ez a beállítás torzíthat, károsíthatja a hangszórót és a hallásodat. Biztosan alkalmazod védelem nélkül?' 'Nagyon erős beállítás' 'YesNo' 'Warning' $window
            if ($warning -ne 'Yes') { return }
        }
        # Reserve headroom for both the volume preamp and overlapping bass filters.
        # This prevents the harsh digital clipping heard with the previous preset.
        $profileHeadroom = if ($script:activeProfile -like 'FiveM*' -or $script:activeProfile -eq 'R6') { 0.5 } else { 0.0 }
        if (-not $SafetyCheck.IsChecked) {
            $safetyReduction = 0.0
        } elseif ($script:activeProfile -eq 'Music') {
            # Music uses gentler protection so it stays lively, while the EQ cuts
            # muddy mids and reserves enough room for bass and treble transients.
            $safetyReduction = [Math]::Min(10.0, ($bassDb * 0.40) + ($maxEqGain * 0.80) + 0.7)
        } else {
            $safetyReduction = [Math]::Min(12.0, [Math]::Max(0.0, ($bassDb * 0.40) + ($maxEqGain * 0.80) + $profileHeadroom))
        }
        $preampDb = if ($volumePercent -le 0) { -100.0 } else { $volumeDb - $safetyReduction }

        $subGain = $bassDb * 0.30
        $mainBassGain = $bassDb * 0.55
        $punchGain = $bassDb * 0.15

        $ownConfig = Join-Path $apoDirectory 'SoundLift.txt'
        $mainConfig = Join-Path $apoDirectory 'config.txt'
        $backupConfig = Join-Path $apoDirectory 'config.before-SoundLift.bak'
        if ((Test-Path $mainConfig) -and (-not (Test-Path $backupConfig))) { [IO.File]::Copy($mainConfig, $backupConfig, $false) }
        if (Test-Path $ownConfig) { [IO.File]::Copy($ownConfig, "$ownConfig.undo", $true) }
        $content = @(
            '# SoundLift - managed configuration',
            ('# Volume: {0}% | Bass: {1} dB | Frequency: {2} Hz | Protection: {3}' -f [int]$volumePercent, [int]$bassDb, $frequency, $SafetyCheck.IsChecked),
            ('Preamp: {0} dB' -f $preampDb.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)),
            ('Filter 1: ON LS Fc 45 Hz Gain {0} dB' -f $subGain.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)),
            ('Filter 2: ON PK Fc {0} Hz Gain {1} dB Q 0.90' -f $frequency, $mainBassGain.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)),
            ('Filter 3: ON PK Fc 115 Hz Gain {0} dB Q 1.10' -f $punchGain.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)),
            'Filter 4: ON HPQ Fc 25 Hz Q 0.71'
        )
        $filterNumber = 10
        for ($i = 0; $i -lt $script:eqBands.Count; $i++) {
            $gain = [double]$script:eqSliders[$i].Value
            if ([Math]::Abs($gain) -ge 0.1) {
                $gainText = $gain.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
                $content += ('Filter {0}: ON PK Fc {1} Hz Gain {2} dB Q 1.00' -f $filterNumber, $script:eqBands[$i], $gainText)
                $filterNumber++
            }
        }
        Write-LinesWithRetry $ownConfig $content

        $includeLine = 'Include: SoundLift.txt'
        $mainText = if (Test-Path $mainConfig) { Read-TextWithRetry $mainConfig } else { '' }
        # Remove the previous managed SoundLift block regardless of the file
        # name used by an older build, then add one clean current block.
        $mainText = [Regex]::Replace($mainText, '(?im)^\s*#\s*SoundLift\s*\r?\n\s*Include:[^\r\n]+\r?\n?', '')
        $mainText = [Regex]::Replace($mainText, '(?im)^\s*Include:\s*SoundLift\.txt\s*\r?\n?', '')
        $mainText = $mainText.TrimEnd() + "`r`n`r`n# SoundLift`r`n$includeLine`r`n"
        Write-TextWithRetry $mainConfig $mainText
        $script:isBypassed = $false
        $StatusText.Text = "Beállítások alkalmazva • $([int]$volumePercent)% hangerő • $([int]$bassDb) dB basszus"
        $StatusBorder.Background = '#143126'
    } catch {
        Write-SoundLiftLog -Category crash -EventName 'handled_runtime_error' -Severity error -Data @{ component='apply_audio_config' } -ErrorRecord $_
        Show-SoundLiftMessage "Nem sikerült menteni:`n$($_.Exception.Message)" 'SoundLift – hiba' 'OK' 'Error' $window | Out-Null
    } finally {
        $script:applyBusy = $false
    }
})

function Invoke-ApplyButton {
    $args = New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)
    $ApplyButton.RaiseEvent($args)
}

function Get-AppState {
    return [PSCustomObject]@{
        version = 10; profile = $script:activeProfile; theme = $script:themeName
        onboardingCompleted = [bool]$script:onboardingCompleted
        volume = [int]$VolumeSlider.Value; bass = [int]$BassSlider.Value; frequency = [int]$FrequencySlider.Value
        safety = [bool]$SafetyCheck.IsChecked; autoProfile = $false; instant = [bool]$InstantCheck.IsChecked
        doNotDisturb = [bool]$DoNotDisturbCheck.IsChecked
        nightMode = $false
        profileOverlay = $false
        discordPresence = $false
        profileOrder = @($script:profileOrder)
        hiddenProfiles = @($script:hiddenProfiles)
        hotkeys = @($script:hotKeyBindings | ForEach-Object { [PSCustomObject]@{ modifiers=[int]$_.modifiers; key=[int]$_.key } })
        eq = @($script:eqSliders | ForEach-Object { [int]$_.Value })
    }
}

function Set-AppState($state) {
    if (-not $state) { return }
    $script:activeProfile = if ($state.profile) { [string]$state.profile } else { 'Custom' }
    Set-Profile ([int]$state.volume) ([int]$state.bass) ([int]$state.frequency) ([bool]$state.safety)
    if ($state.eq -and $state.eq.Count -eq 10) { Set-EqValues ([double[]]$state.eq) }
    $AutoProfileCheck.IsChecked = $false
    if ($null -ne $state.instant) { $InstantCheck.IsChecked = [bool]$state.instant }
    if ($null -ne $state.doNotDisturb) { $DoNotDisturbCheck.IsChecked = [bool]$state.doNotDisturb; $script:doNotDisturb = [bool]$state.doNotDisturb }
    $NightModeCheck.IsChecked = $false
    $OverlayCheck.IsChecked = $false; $script:profileOverlayEnabled = $false
    $DiscordPresenceCheck.IsChecked = $false
    if ($state.profileOrder) { $script:profileOrder=@($state.profileOrder | ForEach-Object {[string]$_}) }
    if ($state.hiddenProfiles) { $script:hiddenProfiles=@($state.hiddenProfiles | ForEach-Object {[string]$_}) }
    Apply-ProfileLayout
    if ($state.hotkeys -and $state.hotkeys.Count -eq 7) {
        if ($state.hotkeys[0] -is [ValueType]) {
            # V1.3.19 és korábbi beállítások: Ctrl+Alt + eltárolt virtuális billentyű.
            $candidateKeys = @($state.hotkeys | ForEach-Object { [int]$_ })
            if ((@($candidateKeys | Select-Object -Unique)).Count -eq 7) {
                $script:hotKeyVirtualKeys = $candidateKeys
                $script:hotKeyBindings = @($candidateKeys | ForEach-Object { [PSCustomObject]@{ modifiers=3; key=[int]$_ } })
            }
        } else {
            $candidateBindings = @($state.hotkeys | ForEach-Object { [PSCustomObject]@{ modifiers=[int]$_.modifiers; key=[int]$_.key } })
            $signatures = @($candidateBindings | ForEach-Object { "$($_.modifiers):$($_.key)" })
            if ((@($signatures | Select-Object -Unique)).Count -eq 7) {
                $script:hotKeyBindings = $candidateBindings
                $script:hotKeyVirtualKeys = @($candidateBindings | ForEach-Object { [int]$_.key })
            }
        }
    }
    if ($state.theme) {
        $savedTheme = switch ([string]$state.theme) { 'Black & Red' {'Fekete és piros'} 'Black & Blue' {'Fekete és kék'} 'Graphite & Green' {'Grafit és zöld'} 'Világos' {'Fekete és piros'} default {[string]$state.theme} }
        if ($script:themeNames -contains $savedTheme) { $ThemeCombo.SelectedItem = $savedTheme; Set-AppTheme $savedTheme }
    }
    if ($null -ne $state.onboardingCompleted) { $script:onboardingCompleted = [bool]$state.onboardingCompleted }
}

$appDataDirectory = Join-Path $env:APPDATA 'SoundLift'
if (-not (Test-Path $appDataDirectory)) { [void][IO.Directory]::CreateDirectory($appDataDirectory) }
$settingsPath = Join-Path $appDataDirectory 'settings.json'
$customProfilePath = Join-Path $appDataDirectory 'custom-profile.json'
$onboardingMarkerPath = Join-Path $appDataDirectory 'first-run-completed.txt'
$updateStatePath = Join-Path $appDataDirectory 'pending-update.json'
$statisticsPath = Join-Path $appDataDirectory 'statistics.json'
$microphoneSettingsPath = Join-Path $appDataDirectory 'microphone-settings.json'

function New-SoundLiftStatistics {
    return [PSCustomObject]@{ totalSeconds=[int64]0; launches=[int64]0; profileSwitches=[int64]0; clippingWarnings=[int64]0; profiles=[PSCustomObject]@{}; lastSavedUtc=[DateTime]::UtcNow.ToString('o') }
}
try {
    $script:statistics = if (Test-Path $statisticsPath) { Get-Content -LiteralPath $statisticsPath -Raw | ConvertFrom-Json } else { New-SoundLiftStatistics }
} catch { $script:statistics = New-SoundLiftStatistics }
foreach($required in @('totalSeconds','launches','profileSwitches','clippingWarnings')) { if(-not $script:statistics.PSObject.Properties[$required]){$script:statistics|Add-Member -NotePropertyName $required -NotePropertyValue ([int64]0)} }
if(-not $script:statistics.profiles){$script:statistics|Add-Member -NotePropertyName profiles -NotePropertyValue ([PSCustomObject]@{}) -Force}
$script:statistics.launches=[int64]$script:statistics.launches+1

function Save-SoundLiftStatistics {
    if(-not $script:statistics){return}
    $elapsed=[Math]::Max(0,([DateTime]::UtcNow-$script:sessionStartedUtc).TotalSeconds)
    $script:statistics.totalSeconds=[int64]$script:statistics.totalSeconds+[int64]$elapsed
    $script:sessionStartedUtc=[DateTime]::UtcNow; $script:statistics.lastSavedUtc=[DateTime]::UtcNow.ToString('o')
    try{$script:statistics|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $statisticsPath -Encoding UTF8}catch{}
}

function Get-DiagnosticsReport {
    $lines = New-Object Collections.Generic.List[string]
    $errors = 0
    $warnings = 0
    $activeOutput = [AudioAppNative]::GetDefaultOutputName()
    $apo = Get-ApoConfigDirectory

    $lines.Add('SOUNDLIFT – AUTOMATIKUS DIAGNOSZTIKA')
    $lines.Add(('=' * 48))
    $lines.Add("Időpont: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $lines.Add("Alkalmazásverzió: $script:appVersion")
    $lines.Add("Támogatási ID: $(Get-SoundLiftSupportId)")
    $lines.Add("Windows: $([Environment]::OSVersion.VersionString)")
    $lines.Add("Aktív hangkimenet: $activeOutput")
    $lines.Add('')

    if (Test-Administrator) {
        $lines.Add('[OK] Rendszergazdai jogosultság aktív.')
    } else {
        $lines.Add('[HIBA] Az alkalmazás nem rendszergazdaként fut.')
        $errors++
    }

    if ($apo) {
        $lines.Add("[OK] Equalizer APO konfigurációs mappa: $apo")
        $mainConfig = Join-Path $apo 'config.txt'
        $boosterConfig = Join-Path $apo 'SoundLift.txt'

        if (Test-Path $mainConfig) {
            $lines.Add('[OK] Az Equalizer APO config.txt fájlja megtalálható.')
            try {
                $mainText = [IO.File]::ReadAllText($mainConfig)
                if ($mainText -match '(?im)^\s*Include:\s*SoundLift\.txt\s*$') {
                    $lines.Add('[OK] A SoundLift kapcsolata aktív a config.txt fájlban.')
                } else {
                    $lines.Add('[HIBA] Hiányzik a SoundLift kapcsolata a config.txt fájlból.')
                    $errors++
                }
            } catch {
                $lines.Add("[HIBA] A config.txt nem olvasható: $($_.Exception.Message)")
                $errors++
            }
        } else {
            $lines.Add('[HIBA] Az Equalizer APO config.txt fájlja hiányzik.')
            $errors++
        }

        if (Test-Path $boosterConfig) {
            try {
                $boosterText = [IO.File]::ReadAllText($boosterConfig)
                if ($boosterText -match '(?im)^\s*Preamp:' -and $boosterText -match '(?im)^\s*Filter(?:\s+\d+)?:') {
                    $lines.Add('[OK] A SoundLift hangbeállításai érvényesek.')
                } else {
                    $lines.Add('[FIGYELEM] A SoundLift hangbeállításai hiányosak. Kattints a Beállítások alkalmazása gombra.')
                    $warnings++
                }
            } catch {
                $lines.Add("[HIBA] A SoundLift hangbeállításai nem olvashatók: $($_.Exception.Message)")
                $errors++
            }
        } else {
            $lines.Add('[FIGYELEM] Még nincs alkalmazott SoundLift-beállítás. Válassz profilt, majd alkalmazd.')
            $warnings++
        }
    } else {
        $lines.Add('[HIBA] Az Equalizer APO telepítése nem található.')
        $errors++
    }

    $conflictProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match 'JBL|Quantum|SteelSeries|Sonar|Nahimic|SonicStudio'
    } | Select-Object -ExpandProperty ProcessName -Unique)
    if ($conflictProcesses.Count -gt 0) {
        $lines.Add("[FIGYELEM] Lehetséges gyártói hangprogram: $($conflictProcesses -join ', ')")
        $lines.Add('           Ha nincs hangváltozás, ez ütközhet az Equalizer APO-val.')
        $warnings++
    } else {
        $lines.Add('[OK] Nem látható ismert, ütközést okozó hangprogram-folyamat.')
    }

    $lines.Add('')
    $lines.Add('FONTOS: azt, hogy az APO ténylegesen az aktív eszközre van-e telepítve,')
    $lines.Add('a Device Selector Status oszlopában kell ellenőrizni.')
    $lines.Add('')
    if ($errors -eq 0 -and $warnings -eq 0) {
        $lines.Add('EREDMÉNY: Nem található nyilvánvaló hiba.')
    } elseif ($errors -eq 0) {
        $lines.Add("EREDMÉNY: $warnings figyelmeztetés található.")
    } else {
        $lines.Add("EREDMÉNY: $errors hiba és $warnings figyelmeztetés található.")
    }
    return $lines -join [Environment]::NewLine
}

function Show-DiagnosticsWindow {
    $report = Get-DiagnosticsReport
    $dialog = [Windows.Window]::new()
    $dialog.Title = "SoundLift $script:appVersion – Diagnosztika"
    $dialog.Width = 760; $dialog.Height = 590; $dialog.MinWidth = 620; $dialog.MinHeight = 440
    $dialog.WindowStartupLocation = 'CenterOwner'; $dialog.Owner = $window
    Set-SoundLiftWindowStyle $dialog

    $grid = [Windows.Controls.Grid]::new()
    $grid.Margin = [Windows.Thickness]::new(18)
    $grid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
    $buttonRow = [Windows.Controls.RowDefinition]::new(); $buttonRow.Height = [Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($buttonRow)

    $reportBox = [Windows.Controls.TextBox]::new()
    $reportBox.Text = $report; $reportBox.IsReadOnly = $true
    $reportBox.AcceptsReturn = $true; $reportBox.TextWrapping = 'NoWrap'
    $reportBox.VerticalScrollBarVisibility = 'Auto'; $reportBox.HorizontalScrollBarVisibility = 'Auto'
    $reportBox.FontFamily = [Windows.Media.FontFamily]::new('Consolas'); $reportBox.FontSize = 13
    $reportBox.Padding = [Windows.Thickness]::new(14)
    $reportBox.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#111113'))
    $reportBox.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#F8FAFC'))
    $reportBox.BorderBrush = $window.Resources['AccentTextBrush']
    [Windows.Controls.Grid]::SetRow($reportBox, 0); $grid.Children.Add($reportBox) | Out-Null

    $buttons = [Windows.Controls.StackPanel]::new()
    $buttons.Orientation = 'Horizontal'; $buttons.HorizontalAlignment = 'Right'
    $buttons.Margin = [Windows.Thickness]::new(0, 12, 0, 0)
    $copyButton = [Windows.Controls.Button]::new(); $copyButton.Content = 'Jelentés másolása'; $copyButton.Margin = [Windows.Thickness]::new(0,0,8,0)
    $saveButton = [Windows.Controls.Button]::new(); $saveButton.Content = 'Mentés TXT-be'; $saveButton.Margin = [Windows.Thickness]::new(0,0,8,0)
    $closeButton = [Windows.Controls.Button]::new(); $closeButton.Content = 'Bezárás'
    $copyButton.Add_Click({
        $copied = $false
        for ($attempt = 1; $attempt -le 10 -and -not $copied; $attempt++) {
            try {
                [Windows.Forms.Clipboard]::SetText($report)
                $copied = $true
            } catch {
                if ($attempt -lt 10) { Start-Sleep -Milliseconds 120 }
            }
        }
        if ($copied) {
            $StatusText.Text = 'A diagnosztikai jelentés a vágólapra került'
        } else {
            Show-SoundLiftMessage 'A Windows vágólapja jelenleg foglalt. Zárd be a vágólapot használó programot, majd próbáld újra.' 'Másolási hiba' 'OK' 'Warning' $dialog | Out-Null
        }
    }.GetNewClosure())
    $saveButton.Add_Click({
        $saveDialog = [Microsoft.Win32.SaveFileDialog]::new()
        $saveDialog.Filter = 'Szövegfájl (*.txt)|*.txt'
        $saveDialog.FileName = "SoundLift-diagnosztika-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        if ($saveDialog.ShowDialog()) { [IO.File]::WriteAllText($saveDialog.FileName, $report, [Text.Encoding]::UTF8) }
    }.GetNewClosure())
    $closeButton.Add_Click({ $dialog.Close() }.GetNewClosure())
    $buttons.Children.Add($copyButton) | Out-Null; $buttons.Children.Add($saveButton) | Out-Null; $buttons.Children.Add($closeButton) | Out-Null
    [Windows.Controls.Grid]::SetRow($buttons, 1); $grid.Children.Add($buttons) | Out-Null
    $dialog.Content = $grid
    $dialog.ShowDialog() | Out-Null
}

$DiagnosticsButton.Add_Click({ Show-DiagnosticsWindow })

function Get-SoundLiftApoHealth {
    $apoDirectory = Get-ApoConfigDirectory
    if (-not $apoDirectory) { return [PSCustomObject]@{ Healthy=$false; Code='APO_NOT_FOUND'; Message='Az Equalizer APO nem található.' } }
    $mainConfig = Join-Path $apoDirectory 'config.txt'
    if (-not (Test-Path $mainConfig)) { return [PSCustomObject]@{ Healthy=$false; Code='CONFIG_MISSING'; Message='Az Equalizer APO config.txt fájlja hiányzik.' } }
    try { $mainText = Read-TextWithRetry $mainConfig } catch { return [PSCustomObject]@{ Healthy=$false; Code='CONFIG_UNREADABLE'; Message='Az Equalizer APO konfigurációja nem olvasható.' } }
    if ($mainText -notmatch '(?im)^\s*Include:\s*SoundLift\.txt\s*$') { return [PSCustomObject]@{ Healthy=$false; Code='INCLUDE_MISSING'; Message='A SoundLift APO-kapcsolata hiányzik.' } }
    $ownConfig = Join-Path $apoDirectory 'SoundLift.txt'
    if (-not (Test-Path $ownConfig)) { return [PSCustomObject]@{ Healthy=$false; Code='SOUNDLIFT_CONFIG_MISSING'; Message='A SoundLift hangkonfigurációja hiányzik.' } }
    try { $ownText = Read-TextWithRetry $ownConfig } catch { return [PSCustomObject]@{ Healthy=$false; Code='SOUNDLIFT_CONFIG_UNREADABLE'; Message='A SoundLift hangkonfigurációja nem olvasható.' } }
    if ($ownText -notmatch '(?im)^\s*Preamp:\s*-?[0-9]+(?:[.,][0-9]+)?\s*dB\s*$') { return [PSCustomObject]@{ Healthy=$false; Code='SOUNDLIFT_CONFIG_INVALID'; Message='A SoundLift hangkonfigurációja sérült.' } }
    return [PSCustomObject]@{ Healthy=$true; Code='OK'; Message='A SoundLift hangkapcsolata megfelelő.' }
}

function Repair-SoundLiftApoInclude([switch]$Automatic) {
    $repairCode = 'UNKNOWN'
    try {
        $before = Get-SoundLiftApoHealth; $repairCode = [string]$before.Code
        if ($before.Healthy) {
            if (-not $Automatic) { Show-SoundLiftMessage 'Nincs szükség javításra: a SoundLift hangkapcsolata megfelelő.' 'SoundLift – APO javítás' 'OK' 'Information' $window | Out-Null }
            return $true
        }
        $apoDirectory = Get-ApoConfigDirectory
        if (-not $apoDirectory) { throw 'APO_NOT_FOUND: Az Equalizer APO konfigurációs mappája nem található.' }
        $mainConfig = Join-Path $apoDirectory 'config.txt'
        if (-not (Test-Path $mainConfig)) { throw 'CONFIG_MISSING: Az Equalizer APO config.txt fájlja nem található.' }
        $mainText = Read-TextWithRetry $mainConfig
        $backupPath = Join-Path $apoDirectory 'config.before-SoundLift-repair.bak'
        if (-not (Test-Path $backupPath)) { [IO.File]::Copy($mainConfig, $backupPath, $false) }
        $mainText = [Regex]::Replace($mainText, '(?im)^\s*#\s*SoundLift\s*\r?\n\s*Include:[^\r\n]+\r?\n?', '')
        $mainText = [Regex]::Replace($mainText, '(?im)^\s*Include:\s*SoundLift(?:[ .][^\r\n]*)?\.txt\s*\r?\n?', '')
        $mainText = $mainText.TrimEnd() + "`r`n`r`n# SoundLift`r`nInclude: SoundLift.txt`r`n"
        Write-TextWithRetry $mainConfig $mainText
        $intermediate = Get-SoundLiftApoHealth
        if ($intermediate.Code -in @('SOUNDLIFT_CONFIG_MISSING','SOUNDLIFT_CONFIG_UNREADABLE','SOUNDLIFT_CONFIG_INVALID')) { Invoke-ApplyButton }
        $after = Get-SoundLiftApoHealth
        if (-not $after.Healthy) { throw "REPAIR_VERIFY_FAILED: $($after.Code)" }
        $StatusText.Text = 'Az APO-kapcsolat sikeresen helyreállt'
        $StatusBorder.Background = '#143126'
        Write-SoundLiftLog -Category startup -EventName 'automatic_repair_result' -Data @{ result='success'; code=$repairCode; component='apo_config' }
        if (-not $Automatic) { Show-SoundLiftMessage "A SoundLift hangkapcsolata sikeresen helyreállt.`n`nAz eredeti config.txt biztonsági mentése is elkészült." 'SoundLift – APO javítás' 'OK' 'Information' $window | Out-Null }
        return $true
    } catch {
        $shortCode = if ($_.Exception.Message -match '^([A-Z_]+):') { $Matches[1] } else { $repairCode }
        Write-SoundLiftLog -Category crash -EventName 'automatic_repair_result' -Severity error -Data @{ result='failed'; code=$shortCode; component='apo_config' } -ErrorRecord $_
        $StatusText.Text = "Az APO-kapcsolat nem javítható: $($_.Exception.Message)"
        $StatusBorder.Background = '#4A1F2D'
        if (-not $Automatic) { Show-SoundLiftMessage "A javítás nem sikerült ($shortCode):`n$($_.Exception.Message)" 'SoundLift – APO javítás' 'OK' 'Error' $window | Out-Null }
        return $false
    }
}

function Test-AndOfferSoundLiftRepair {
    $health = Get-SoundLiftApoHealth
    if ($health.Healthy) { return }
    $answer = Show-SoundLiftMessage "$($health.Message)`n`nHibakód: $($health.Code)`n`nMegpróbálja a SoundLift egy kattintással kijavítani?" 'SoundLift – Javítás szükséges' 'YesNo' 'Warning' $window
    if ($answer -eq 'Yes') {
        if (Repair-SoundLiftApoInclude -Automatic) { Show-SoundLiftMessage 'A javítás sikerült. A hangkapcsolat ismét működik.' 'SoundLift – Javítás kész' 'OK' 'Information' $window | Out-Null }
        else { Show-SoundLiftMessage 'Az automatikus javítás nem sikerült. Nyisd meg a Rendszer ellenőrzése részt a részletekért.' 'SoundLift – Javítás sikertelen' 'OK' 'Error' $window | Out-Null }
    }
}

$RepairApoButton.Add_Click({
    $answer = Show-SoundLiftMessage 'A SoundLift ellenőrzi és szükség esetén kijavítja az Equalizer APO Include sorát. Folytatod?' 'SoundLift – APO automatikus javítás' 'YesNo' 'Question' $window
    if ($answer -eq 'Yes') { Repair-SoundLiftApoInclude }
})

function Test-SoundLiftProblemReportService {
    Initialize-SoundLiftLogger
    return ($script:loggerInitialized -and -not [string]::IsNullOrWhiteSpace($script:logApiUrl))
}

function Test-SoundLiftProblemReportQueued {
    return (-not [string]::IsNullOrWhiteSpace($script:logQueueFile) -and (Test-Path $script:logQueueFile) -and (Get-Item -LiteralPath $script:logQueueFile).Length -gt 0)
}

function Show-ProblemReportWindow {
    $report = Get-DiagnosticsReport
    $dialog = [Windows.Window]::new(); $dialog.Title = 'SoundLift – Hiba jelentése'
    $dialog.Width = 800; $dialog.Height = 720; $dialog.MinWidth = 680; $dialog.MinHeight = 580
    $dialog.WindowStartupLocation = 'CenterOwner'; $dialog.Owner = $window
    Set-SoundLiftWindowStyle $dialog
    $root = [Windows.Controls.Grid]::new(); $root.Margin = [Windows.Thickness]::new(22)
    $auto = [Windows.GridLength]::Auto
    foreach ($height in @($auto,$auto,$auto,$auto,[Windows.GridLength]::new(1,[Windows.GridUnitType]::Star),$auto,$auto)) { $row=[Windows.Controls.RowDefinition]::new(); $row.Height=$height; $root.RowDefinitions.Add($row) }
    $heading = [Windows.Controls.TextBlock]::new(); $heading.Text = 'Hiba jelentése'; $heading.FontSize = 25; $heading.FontWeight = 'Bold'; $heading.Foreground = $window.Resources['AccentTextBrush']; $heading.Margin = [Windows.Thickness]::new(0,0,0,16)
    $descriptionLabel=[Windows.Controls.TextBlock]::new(); $descriptionLabel.Text='Írd le röviden, mi történt (opcionális)'; $descriptionLabel.FontSize=13; $descriptionLabel.FontWeight='SemiBold'; $descriptionLabel.Margin=[Windows.Thickness]::new(0,0,0,7)
    $description=[Windows.Controls.TextBox]::new(); $description.Height=78; $description.MaxLength=1000; $description.AcceptsReturn=$true; $description.TextWrapping='Wrap'; $description.VerticalScrollBarVisibility='Auto'; $description.Padding=12; $description.Background=$window.Resources['SurfaceBrush']; $description.Foreground=$window.Resources['PrimaryTextBrush']; $description.BorderBrush=$window.Resources['BorderBrush']; $description.BorderThickness=1; $description.Margin=[Windows.Thickness]::new(0,0,0,15)
    $previewLabel=[Windows.Controls.TextBlock]::new(); $previewLabel.Text='Küldés előtti adat-előnézet'; $previewLabel.FontSize=13; $previewLabel.FontWeight='SemiBold'; $previewLabel.Margin=[Windows.Thickness]::new(0,0,0,7)
    $box = [Windows.Controls.TextBox]::new(); $box.IsReadOnly=$true; $box.AcceptsReturn=$true; $box.TextWrapping='NoWrap'; $box.VerticalScrollBarVisibility='Auto'; $box.HorizontalScrollBarVisibility='Auto'; $box.FontFamily='Consolas'; $box.FontSize=12; $box.Padding=14; $box.Background=$window.Resources['SurfaceBrush']; $box.Foreground=$window.Resources['PrimaryTextBrush']; $box.BorderBrush=$window.Resources['BorderBrush']; $box.BorderThickness=1
    $refreshPreview = {
        $userText = if ([string]::IsNullOrWhiteSpace($description.Text)) { '(nincs megadva)' } else { $description.Text.Trim() }
        $box.Text = "FELHASZNÁLÓ LEÍRÁSA`r`n$userText`r`n`r`n$report"
    }.GetNewClosure()
    $description.Add_TextChanged($refreshPreview); & $refreshPreview
    $privacy = [Windows.Controls.TextBlock]::new(); $privacy.Text='ADATVÉDELEM  •  A jelentés nem tartalmaz licenckulcsot, webhookot, jelszót vagy teljes gépazonosítót. Az adatok csak a Jelentés elküldése gomb megnyomása után kerülnek továbbításra.'; $privacy.TextWrapping='Wrap'; $privacy.Foreground=$window.Resources['SecondaryTextBrush']; $privacy.Background=$window.Resources['ControlBrush']; $privacy.Padding=[Windows.Thickness]::new(12,10,12,10); $privacy.Margin=[Windows.Thickness]::new(0,12,0,12)
    $buttons=[Windows.Controls.StackPanel]::new(); $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'
    $cancel=[Windows.Controls.Button]::new(); $cancel.Content='Mégse'; $cancel.Width=105; $cancel.Margin=[Windows.Thickness]::new(0,0,10,0); $cancel.Style=$window.Resources['UtilityButton']
    $send=[Windows.Controls.Button]::new(); $send.Content='Jelentés elküldése'; $send.Width=180; $send.Style=$window.Resources['PrimaryButton']
    $cancel.Add_Click({ $dialog.Close() }.GetNewClosure())
    $send.Add_Click({
        if (-not (Test-SoundLiftProblemReportService)) {
            Show-SoundLiftMessage 'A hibajelentő szolgáltatás nincs beállítva ebben a példányban. Telepítsd a hivatalos SoundLift-verziót, majd próbáld újra.' 'SoundLift – Hiba jelentése' 'OK' 'Warning' $dialog | Out-Null
            return
        }
        $send.IsEnabled=$false; $send.Content='Küldés folyamatban…'; [Windows.Forms.Application]::DoEvents()
        try {
            $submittedDescription = if ([string]::IsNullOrWhiteSpace($description.Text)) { '(nincs megadva)' } else { $description.Text.Trim() }
            Write-SoundLiftLog -Category crash -EventName 'manual_diagnostic_report' -Severity warning -Data @{ user_description=$submittedDescription; diagnostic_report=$report; submitted_by_user='true' }
            if (-not (Test-SoundLiftProblemReportQueued)) { throw 'A jelentés helyi előkészítése sikertelen volt.' }
            $sent = Send-SoundLiftPendingLogs
            $StatusText.Text = if ($sent) { 'A hibajelentést sikeresen elküldtük' } else { 'A hibajelentést mentettük, a következő indításkor újraküldjük' }
            $StatusBorder.Background = if ($sent) { '#143126' } else { '#4A3514' }
            $dialog.Close()
            $resultText = if ($sent) { 'A jelentést sikeresen elküldtük.' } else { 'A jelentést biztonságosan elmentettük, és a következő indításkor automatikusan újraküldjük.' }
            Show-SoundLiftMessage "$resultText`nTámogatási ID: $(Get-SoundLiftSupportId)" 'SoundLift – Hiba jelentése' 'OK' 'Information' $dialog | Out-Null
        } catch {
            $send.IsEnabled=$true; $send.Content='Újrapróbálás'
            Show-SoundLiftMessage "A jelentés elküldése nem sikerült:`n$($_.Exception.Message)" 'SoundLift – Hiba jelentése' 'OK' 'Error' $dialog | Out-Null
        }
    }.GetNewClosure())
    $buttons.Children.Add($cancel)|Out-Null; $buttons.Children.Add($send)|Out-Null
    foreach($pair in @(@($heading,0),@($descriptionLabel,1),@($description,2),@($previewLabel,3),@($box,4),@($privacy,5),@($buttons,6))){ [Windows.Controls.Grid]::SetRow($pair[0],$pair[1]); $root.Children.Add($pair[0])|Out-Null }
    $dialog.Content=$root; $dialog.ShowDialog()|Out-Null
}

$ReportProblemButton.Add_Click({ Show-ProblemReportWindow })

function Get-SoundLiftRollbackState {
    $rollbackDirectory = Join-Path $script:appDirectory 'rollback'
    $backupPath = Join-Path $rollbackDirectory 'SoundLift.previous.exe'
    $statePath = Join-Path $rollbackDirectory 'rollback-state.json'
    if (-not (Test-Path $backupPath) -or -not (Test-Path $statePath)) { return $null }
    try {
        $state = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace([string]$state.sha256) -or [string]::IsNullOrWhiteSpace([string]$state.version)) { return $null }
        $backupVersion = [version]([string]$state.version)
        if ($backupVersion -ge [version]$script:appVersion) { return $null }
        $actualHash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($actualHash -ne ([string]$state.sha256).ToLowerInvariant()) { return $null }
        return [PSCustomObject]@{ path=$backupPath; version=[string]$state.version; sha256=$actualHash }
    } catch { return $null }
}

function Save-SoundLiftRollbackCopy {
    if ($script:currentLicenseType -ne 'developer') { return }
    if (-not $script:isPackagedExe -or -not (Test-Path $script:appLaunchPath)) { throw 'A futó alkalmazás nem menthető visszaállításhoz.' }
    $rollbackDirectory = Join-Path $script:appDirectory 'rollback'
    [IO.Directory]::CreateDirectory($rollbackDirectory) | Out-Null
    $backupPath = Join-Path $rollbackDirectory 'SoundLift.previous.exe'
    [IO.File]::Copy($script:appLaunchPath, $backupPath, $true)
    $hash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $state = @{ version=$script:appVersion; sha256=$hash; created_utc=[DateTime]::UtcNow.ToString('o') }
    [IO.File]::WriteAllText((Join-Path $rollbackDirectory 'rollback-state.json'), ($state | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
}

function Restore-SoundLiftPreviousVersion {
    if ($script:currentLicenseType -ne 'developer') {
        Write-SoundLiftLog -Category security -EventName 'license_rejected' -Severity warning -Data @{ code='ROLLBACK_NOT_DEVELOPER' }
        return
    }
    $state = Get-SoundLiftRollbackState
    if (-not $state) { Show-SoundLiftMessage 'Nem található sértetlen előző verzió.' 'SoundLift – Visszaállítás' 'OK' 'Warning' $window | Out-Null; return }
    $answer = Show-SoundLiftMessage "Biztosan visszaállítod a SoundLift $($state.version) verzióját?`n`nA program újra fog indulni." 'SoundLift – Előző verzió' 'YesNo' 'Warning' $window
    if ($answer -ne 'Yes') { return }
    try {
        $targetPath = $script:appLaunchPath
        $command = "Start-Sleep -Seconds 2; `$actual=(Get-FileHash -LiteralPath '$($state.path.Replace("'", "''"))' -Algorithm SHA256).Hash.ToLowerInvariant(); if (`$actual -ne '$($state.sha256)') { exit 2 }; Copy-Item -LiteralPath '$($state.path.Replace("'", "''"))' -Destination '$($targetPath.Replace("'", "''"))' -Force; Start-Process -FilePath '$($targetPath.Replace("'", "''"))'"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        Write-SoundLiftLog -Category update -EventName 'version_changed' -Data @{ old_version=$script:appVersion; new_version=$state.version; result='rollback_started' }
        [void](Send-SoundLiftPendingLogs)
        Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile','-NonInteractive','-WindowStyle','Hidden','-EncodedCommand',$encoded -ErrorAction Stop
        $script:reallyExit=$true; $window.Close()
    } catch { Show-SoundLiftMessage "A visszaállítás nem indítható el:`n$($_.Exception.Message)" 'SoundLift – Visszaállítás' 'OK' 'Error' $window | Out-Null }
}

function Show-OwnerLicenseSimulator {
    if (-not $script:isOwner) {
        Write-SoundLiftLog -Category security -EventName 'owner_mode_rejected' -Severity warning
        return
    }
    $saved = Get-SavedLicenseState
    if (-not $saved -or [string]::IsNullOrWhiteSpace([string]$saved.key)) { return }
    try { $targets = Invoke-LicenseApi ([string]$saved.key) 'list_owner_targets' }
    catch { Show-SoundLiftMessage "A tesztlicencek most nem kérhetők le.`n`n$($_.Exception.Message)" 'SoundLift – Tulajdonosi tesztmód' 'OK' 'Error' $window | Out-Null; return }
    if ($targets.allowed -ne $true -or $targets.is_owner -ne $true) { return }

    $dialog=[Windows.Window]::new(); $dialog.Title='SoundLift – Tulajdonosi és fejlesztői tesztmód'; $dialog.Width=590; $dialog.Height=360
    $dialog.ResizeMode='NoResize'; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Owner=$window; Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.StackPanel]::new(); $root.Margin=[Windows.Thickness]::new(28)
    $title=[Windows.Controls.TextBlock]::new(); $title.Text='Licencjogosultságok szimulálása'; $title.FontSize=23; $title.FontWeight='Bold'
    $info=[Windows.Controls.TextBlock]::new(); $info.Text="A saját tulajdonosi fiókod marad bejelentkezve. A kiválasztás csak a céllicenc funkcióit tölti be teszteléshez; nem lép be a vásárló Discord-fiókjába."; $info.TextWrapping='Wrap'; $info.Foreground='#CBD5E1'; $info.Margin=[Windows.Thickness]::new(0,12,0,16)
    $combo=[Windows.Controls.ComboBox]::new(); $combo.Height=38; $combo.DisplayMemberPath='label'; $combo.SelectedValuePath='license_id'
    [void]$combo.Items.Add([PSCustomObject]@{label='Normál SoundLift (saját tulajdonosi jogosultság)';license_id=''})
    foreach($target in @($targets.targets)){[void]$combo.Items.Add([PSCustomObject]@{label=[string]$target.label;license_id=[string]$target.license_id})}
    $combo.SelectedIndex=0
    $notice=[Windows.Controls.TextBlock]::new(); $notice.Text='Biztonság: a kiszolgáló minden váltásnál újra ellenőrzi a tulajdonosi licencet és a kiválasztott céllicencet.'; $notice.Foreground='#94A3B8'; $notice.Margin=[Windows.Thickness]::new(0,12,0,18)
    $buttons=[Windows.Controls.StackPanel]::new(); $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'
    $cancel=[Windows.Controls.Button]::new(); $cancel.Content='Mégse'; $cancel.Width=105; $cancel.Height=38; $cancel.Margin=[Windows.Thickness]::new(0,0,10,0)
    $apply=[Windows.Controls.Button]::new(); $apply.Content='Tesztmód alkalmazása'; $apply.Width=180; $apply.Height=38
    $selection=@{accepted=$false;id=''}
    $cancel.Add_Click({$dialog.Close()}.GetNewClosure())
    $apply.Add_Click({if($combo.SelectedItem){$selection.accepted=$true;$selection.id=[string]$combo.SelectedValue;$dialog.Close()}}.GetNewClosure())
    foreach($control in @($title,$info,$combo,$notice,$buttons)){[void]$root.Children.Add($control)}
    [void]$buttons.Children.Add($cancel);[void]$buttons.Children.Add($apply);$dialog.Content=$root;[void]$dialog.ShowDialog()
    if(-not $selection.accepted){return}
    try {
        $response=Invoke-LicenseApi ([string]$saved.key) 'verify' $selection.id
        if($response.allowed -eq $true){Set-LicenseResponse $response; if([string]::IsNullOrWhiteSpace($selection.id)){Set-LicenseResponse $response -Persist -licenseKey ([string]$saved.key)}; Update-DeveloperControls; $StatusText.Text=if($script:simulatedLicenseLabel){"Tulajdonosi tesztmód • $($script:simulatedLicenseLabel)"}else{'Tulajdonosi tesztmód kikapcsolva • saját jogosultságok'}}
    } catch {Show-SoundLiftMessage "A tesztmód nem alkalmazható.`n`n$($_.Exception.Message)" 'SoundLift – Tulajdonosi tesztmód' 'OK' 'Error' $dialog|Out-Null}
}

$RollbackButton.Visibility = 'Collapsed'; $RollbackButton.IsEnabled = $false
$RollbackButton.Add_Click({ Restore-SoundLiftPreviousVersion })

function Show-SoundLiftStatistics {
    Save-SoundLiftStatistics
    $total=[TimeSpan]::FromSeconds([double]$script:statistics.totalSeconds)
    $usage=if($total.TotalHours-ge 1){'{0:N1} óra' -f $total.TotalHours}else{'{0} perc' -f [Math]::Round($total.TotalMinutes)}
    $top='Még nincs adat';$topCount=0
    foreach($property in $script:statistics.profiles.PSObject.Properties){if([int64]$property.Value-gt $topCount){$topCount=[int64]$property.Value;$top=Get-SoundLiftProfileDisplayName $property.Name}}
    $dialog=[Windows.Window]::new();$dialog.Title='SoundLift – Statisztikák';$dialog.Width=560;$dialog.Height=500;$dialog.ResizeMode='NoResize';$dialog.WindowStartupLocation='CenterOwner';$dialog.Owner=$window;Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.StackPanel]::new();$root.Margin=[Windows.Thickness]::new(26);$title=[Windows.Controls.TextBlock]::new();$title.Text='Használati statisztikák';$title.FontSize=24;$title.FontWeight='Bold';$title.Foreground=$window.Resources['AccentTextBrush'];[void]$root.Children.Add($title)
    $subtitle=[Windows.Controls.TextBlock]::new();$subtitle.Text='Az adatok kizárólag ezen a gépen kerülnek mentésre.';$subtitle.Foreground='#94A3B8';$subtitle.Margin=[Windows.Thickness]::new(0,5,0,18);[void]$root.Children.Add($subtitle)
    foreach($entry in @(@('Teljes használati idő',$usage),@('Indítások',[string]$script:statistics.launches),@('Profilváltások',[string]$script:statistics.profileSwitches),@('Leggyakoribb profil',"$top ($topCount alkalom)"),@('Clipping figyelmeztetések',[string]$script:statistics.clippingWarnings))){$card=[Windows.Controls.Border]::new();$card.Background='#111113';$card.CornerRadius=[Windows.CornerRadius]::new(10);$card.Padding=[Windows.Thickness]::new(13,9,13,9);$card.Margin=[Windows.Thickness]::new(0,0,0,7);$dock=[Windows.Controls.DockPanel]::new();$label=[Windows.Controls.TextBlock]::new();$label.Text=$entry[0];$label.Foreground='#CBD5E1';$value=[Windows.Controls.TextBlock]::new();$value.Text=$entry[1];$value.Foreground=$window.Resources['AccentTextBrush'];$value.FontWeight='Bold';$value.HorizontalAlignment='Right';[void]$dock.Children.Add($label);[void]$dock.Children.Add($value);$card.Child=$dock;[void]$root.Children.Add($card)}
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.HorizontalAlignment='Right';$actions.Margin=[Windows.Thickness]::new(0,14,0,0)
    $reset=[Windows.Controls.Button]::new();$reset.Content='Statisztikák nullázása';$reset.Style=$window.Resources['UtilityButton'];$reset.Width=180;$reset.Add_Click({if((Show-SoundLiftMessage 'Biztosan törlöd a helyi SoundLift-statisztikákat?' 'SoundLift' 'YesNo' 'Question' $dialog)-eq'Yes'){$script:statistics=New-SoundLiftStatistics;$script:statistics.launches=1;Save-SoundLiftStatistics;$dialog.Close();$StatusText.Text='Statisztikák nullázva'}}.GetNewClosure())
    $close=[Windows.Controls.Button]::new();$close.Content='Rendben';$close.Style=$window.Resources['PrimaryButton'];$close.Width=110;$close.Add_Click({$dialog.Close()}.GetNewClosure());[void]$actions.Children.Add($reset);[void]$actions.Children.Add($close);[void]$root.Children.Add($actions);$dialog.Content=$root;$dialog.ShowDialog()|Out-Null
}
$StatisticsButton.Add_Click({Show-SoundLiftStatistics})

function Show-DeveloperConsole {
    if($script:currentLicenseType -ne 'developer'){
        Write-SoundLiftLog -Category developer_access -EventName 'developer_console_denied' -Severity warning
        Show-SoundLiftMessage 'A Fejlesztői konzol kizárólag érvényes fejlesztői licenccel használható.' 'SoundLift' 'OK' 'Warning' $window|Out-Null;return
    }
    Write-SoundLiftLog -Category developer_access -EventName 'developer_console_opened'
    $dialog=[Windows.Window]::new();$dialog.Title='SoundLift – Fejlesztői konzol';$dialog.Width=920;$dialog.Height=680;$dialog.WindowStartupLocation='CenterOwner';$dialog.Owner=$window;Set-SoundLiftWindowStyle $dialog
    $grid=[Windows.Controls.Grid]::new();$grid.Margin=[Windows.Thickness]::new(20);$grid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new());$bottom=[Windows.Controls.RowDefinition]::new();$bottom.Height=[Windows.GridLength]::Auto;$grid.RowDefinitions.Add($bottom)
    $console=[Windows.Controls.TextBox]::new();$console.IsReadOnly=$true;$console.AcceptsReturn=$true;$console.TextWrapping='NoWrap';$console.VerticalScrollBarVisibility='Auto';$console.HorizontalScrollBarVisibility='Auto';$console.Background='#050505';$console.Foreground='#D1FAE5';$console.FontFamily='Consolas';$console.FontSize=12;$console.Padding=[Windows.Thickness]::new(12)
    $refresh={
        $report=Get-DiagnosticsReport;$logs='Nincs helyi napló.'
        try{$latest=Get-ChildItem -LiteralPath $script:logRoot -Filter 'soundlift-*.ndjson' -File|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1;if($latest){$logs=(Get-Content -LiteralPath $latest.FullName -Tail 120)-join"`r`n"}}catch{}
        $console.Text="SOUNDLIFT FEJLESZTŐI KONZOL`r`nVerzió: $script:appVersion`r`nLicenc: $script:currentLicenseType`r`nProfil: $script:activeProfile`r`n`r`n=== DIAGNOSZTIKA ===`r`n$report`r`n`r`n=== LEGUTÓBBI NAPLÓ ===`r`n$logs";$console.ScrollToEnd()
    }.GetNewClosure(); &$refresh
    [Windows.Controls.Grid]::SetRow($console,0);[void]$grid.Children.Add($console)
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.HorizontalAlignment='Right';$actions.Margin=[Windows.Thickness]::new(0,12,0,0)
    $refreshButton=[Windows.Controls.Button]::new();$refreshButton.Content='Frissítés';$refreshButton.Style=$window.Resources['UtilityButton'];$refreshButton.Width=105;$refreshButton.Add_Click({&$refresh}.GetNewClosure())
    $copy=[Windows.Controls.Button]::new();$copy.Content='Másolás';$copy.Style=$window.Resources['UtilityButton'];$copy.Width=105;$copy.Add_Click({[Windows.Forms.Clipboard]::SetText($console.Text)}.GetNewClosure())
    $logsButton=[Windows.Controls.Button]::new();$logsButton.Content='Naplómappa';$logsButton.Style=$window.Resources['UtilityButton'];$logsButton.Width=120;$logsButton.Add_Click({if(Test-Path $script:logRoot){Start-Process explorer.exe $script:logRoot}}.GetNewClosure())
    $close=[Windows.Controls.Button]::new();$close.Content='Bezárás';$close.Style=$window.Resources['PrimaryButton'];$close.Width=105;$close.Add_Click({$dialog.Close()}.GetNewClosure());foreach($button in @($refreshButton,$copy,$logsButton,$close)){[void]$actions.Children.Add($button)};[Windows.Controls.Grid]::SetRow($actions,1);[void]$grid.Children.Add($actions);$dialog.Content=$grid;$dialog.ShowDialog()|Out-Null
}
$DeveloperConsoleButton.Add_Click({Show-DeveloperConsole})

function Update-DeveloperControls {
    $displayType = switch ($script:currentLicenseType) { 'developer' { 'fejlesztői' } 'customer' { 'vásárlói' } default { 'ingyenes' } }
    $LicenseStatusText.Text = "Licenc: $displayType"
    $LicenseButton.Content = if ($script:currentLicenseType -eq 'free') { '◇  Licenc aktiválása' } else { '◇  Licenc kezelése' }
    $RollbackButton.Visibility = 'Collapsed'; $RollbackButton.IsEnabled = $false
    if ($script:currentLicenseType -eq 'developer') { $DeveloperConsoleButton.Visibility = 'Visible' } else { $DeveloperConsoleButton.Visibility = 'Collapsed'; $DeveloperConsoleButton.IsEnabled = $false }
    if($script:currentLicenseType -eq 'developer'){$DeveloperConsoleButton.IsEnabled=$true}
    $OwnerModeButton.Visibility = 'Collapsed'
    $ExtraBassProButton.Visibility = if($script:licenseFeatures.ContainsKey('extra_bass_pro')){'Visible'}else{'Collapsed'}
    $VoiceBoostButton.Visibility = if($script:licenseFeatures.ContainsKey('voice_boost')){'Visible'}else{'Collapsed'}
    $CustomPresetXButton.Visibility = if($script:licenseFeatures.ContainsKey('custom_preset_x')){'Visible'}else{'Collapsed'}
    $CustomFeaturesTitle.Visibility = if($script:licenseFeatures.Count -gt 0){'Visible'}else{'Collapsed'}
    if($script:simulatedLicenseLabel){$LicenseStatusText.Text="Tulajdonosi teszt: $($script:simulatedLicenseLabel)"}
}

$OwnerModeButton.Add_Click({Show-OwnerLicenseSimulator})

function Show-LicenseManagerWindow {
    $saved = Get-SavedLicenseState
    if (-not $saved -or -not $saved.key) { return }
    $dialog=[Windows.Window]::new();$dialog.Title='SoundLift – Licenckezelő';$dialog.Width=650;$dialog.Height=570;$dialog.MinWidth=560;$dialog.MinHeight=500;$dialog.WindowStartupLocation='CenterOwner';$dialog.Owner=$window;Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.Grid]::new();$root.Margin=[Windows.Thickness]::new(26);$root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new());$actionsRow=[Windows.Controls.RowDefinition]::new();$actionsRow.Height=[Windows.GridLength]::Auto;$root.RowDefinitions.Add($actionsRow)
    $scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto';$panel=[Windows.Controls.StackPanel]::new()
    $title=[Windows.Controls.TextBlock]::new();$title.Text='Licenc adatai';$title.FontSize=25;$title.FontWeight='Bold';$title.Foreground=$window.Resources['PrimaryTextBrush'];$title.Margin=[Windows.Thickness]::new(0,0,0,16)
    $variant=if($script:currentLicenseVariant){$script:currentLicenseVariant}else{'normál'};$statusMap=@{active='aktív';suspended='felfüggesztve';revoked='visszavonva';inactive='inaktív'};$statusText=if($statusMap.ContainsKey($script:currentLicenseStatus)){$statusMap[$script:currentLicenseStatus]}else{$script:currentLicenseStatus}
    $activated='nem érhető el';if($script:currentLicenseActivatedUtc){try{$activated=([DateTime]::Parse($script:currentLicenseActivatedUtc).ToLocalTime()).ToString('yyyy. MM. dd. HH:mm')}catch{}}
    $features=@($script:licenseFeatures.Values|ForEach-Object{if($_.display_name){[string]$_.display_name}else{[string]$_.feature_key}}|Sort-Object);$featureText=if($features.Count){$features-join "`n• "}else{'Nincs külön egyedi funkció'}
    $details=[Windows.Controls.TextBlock]::new();$details.Text="Licenc típusa: $variant`nÁllapot: $statusText`nGéphez kötés: $activated`nGépazonosító röviden: $(if($script:currentLicenseDeviceRef){$script:currentLicenseDeviceRef}else{'nem érhető el'})`n`nEngedélyezett egyedi funkciók:`n• $featureText";$details.TextWrapping='Wrap';$details.FontSize=14;$details.LineHeight=23;$details.Foreground=$window.Resources['SecondaryTextBrush']
    $notice=[Windows.Controls.TextBlock]::new();$notice.Text='A gépcsere-kérelem nem választja le azonnal a jelenlegi gépet. A kérelmet az adminisztrátor ellenőrzi, így a licenced addig is működőképes marad.';$notice.TextWrapping='Wrap';$notice.Margin=[Windows.Thickness]::new(0,20,0,0);$notice.Padding=[Windows.Thickness]::new(14);$notice.Background=$window.Resources['ControlBrush'];$notice.Foreground=$window.Resources['SecondaryTextBrush']
    [void]$panel.Children.Add($title);[void]$panel.Children.Add($details);[void]$panel.Children.Add($notice);$scroll.Content=$panel;[Windows.Controls.Grid]::SetRow($scroll,0);[void]$root.Children.Add($scroll)
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.HorizontalAlignment='Right';$actions.Margin=[Windows.Thickness]::new(0,18,0,0)
    $refresh=[Windows.Controls.Button]::new();$refresh.Content='Adatok frissítése';$refresh.Width=140;$refresh.Style=$window.Resources['UtilityButton'];$refresh.Margin=[Windows.Thickness]::new(0,0,10,0)
    $transfer=[Windows.Controls.Button]::new();$transfer.Content='Gépcsere kérelmezése';$transfer.Width=175;$transfer.Style=$window.Resources['UtilityButton'];$transfer.Margin=[Windows.Thickness]::new(0,0,10,0)
    $close=[Windows.Controls.Button]::new();$close.Content='Bezárás';$close.Width=105;$close.Style=$window.Resources['PrimaryButton'];$close.Add_Click({$dialog.Close()}.GetNewClosure())
    $refresh.Add_Click({try{$response=Invoke-LicenseApi ([string]$saved.key);if($response.allowed){Set-LicenseResponse $response -Persist -licenseKey ([string]$saved.key);Update-DeveloperControls;$dialog.Close();Show-LicenseManagerWindow}}catch{Show-SoundLiftMessage 'A licencadatok most nem frissíthetők.' 'Licenckezelő' 'OK' 'Warning' $dialog|Out-Null}}.GetNewClosure())
    $transfer.Add_Click({$answer=Show-SoundLiftMessage 'Elküldöd a gépcsere-kérelmet? A jelenlegi gép nem kerül automatikusan leválasztásra.' 'SoundLift – Gépcsere' 'YesNo' 'Question' $dialog;if($answer -ne 'Yes'){return};try{$response=Invoke-LicenseApi ([string]$saved.key) 'request_device_change';Show-SoundLiftMessage ([string]$response.message) 'SoundLift – Gépcsere' 'OK' 'Information' $dialog|Out-Null;$transfer.IsEnabled=$false;$transfer.Content='Kérelem elküldve'}catch{Show-SoundLiftMessage "A kérelem nem küldhető el:`n$($_.Exception.Message)" 'SoundLift – Gépcsere' 'OK' 'Error' $dialog|Out-Null}}.GetNewClosure())
    foreach($button in @($refresh,$transfer,$close)){[void]$actions.Children.Add($button)};[Windows.Controls.Grid]::SetRow($actions,1);[void]$root.Children.Add($actions);$dialog.Content=$root;$dialog.ShowDialog()|Out-Null
}

$LicenseButton.Add_Click({
    if ($script:currentLicenseType -ne 'free') { Show-LicenseManagerWindow; return }
    if (Confirm-SoundLiftLicense -PromptForKey) {
        Update-DeveloperControls
        if ($script:currentLicenseType -ne 'free') {
            $StatusText.Text = "$($LicenseStatusText.Text) aktiválva"
        }
    }
})

function Invoke-SoundLiftDownload([string]$uri, [string]$destination, [Windows.Controls.ProgressBar]$progressBar, [Windows.Controls.TextBlock]$statusText, [double]$startPercent, [double]$percentSpan, [string]$label) {
    $request = [Net.HttpWebRequest]::Create($uri)
    $request.UserAgent = "SoundLift/$($script:appVersion)"
    $request.Accept = 'application/octet-stream'
    $request.Timeout = 120000; $request.ReadWriteTimeout = 120000
    $response = $null; $input = $null; $output = $null
    try {
        $response = $request.GetResponse(); $total = [long]$response.ContentLength
        $input = $response.GetResponseStream(); $output = [IO.File]::Create($destination)
        $buffer = New-Object byte[] 65536; $received = [long]0
        while (($count = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $count); $received += $count
            $fraction = if ($total -gt 0) { [Math]::Min(1.0, $received / $total) } else { 0.0 }
            $percent = [Math]::Min(100, [Math]::Round($startPercent + ($fraction * $percentSpan)))
            $progressBar.IsIndeterminate = $total -le 0; if ($total -gt 0) { $progressBar.Value = $percent }
            $statusText.Text = if ($total -gt 0) { "$label – $percent%" } else { "$label…" }
            [Windows.Forms.Application]::DoEvents()
        }
    } finally {
        if ($output) { $output.Dispose() }; if ($input) { $input.Dispose() }; if ($response) { $response.Dispose() }
    }
}

function Install-SoundLiftUpdate([object]$release, [version]$latestVersion, [Windows.Controls.TextBlock]$statusText, [Windows.Controls.Button]$installButton, [Windows.Controls.ProgressBar]$progressBar) {
    $temporaryDirectory = $null
    try {
        $installerAsset = @($release.assets | Where-Object { $_.name -in @('SoundLift.Setup.exe', 'SoundLift Setup.exe') }) | Select-Object -First 1
        $checksumAsset = @($release.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }) | Select-Object -First 1
        if (-not $installerAsset -or -not $checksumAsset) { throw 'A kiadásból hiányzik a telepítő vagy az ellenőrzőösszeg.' }
        foreach ($asset in @($installerAsset, $checksumAsset)) {
            $assetUri = [Uri]([string]$asset.browser_download_url)
            if ($assetUri.Scheme -ne 'https' -or $assetUri.Host -ne 'github.com') { throw 'A frissítés letöltési címe nem engedélyezett.' }
        }
        $installButton.IsEnabled = $false; $installButton.Content = 'Frissítés folyamatban…'; $statusText.Text = 'Letöltés előkészítése…'
        $progressBar.Visibility = 'Visible'; $progressBar.IsIndeterminate = $false; $progressBar.Value = 0
        [Windows.Forms.Application]::DoEvents()
        $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ('SoundLiftUpdate-' + [Guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
        $installerPath = Join-Path $temporaryDirectory 'SoundLift.Setup.exe'
        $checksumPath = Join-Path $temporaryDirectory 'SHA256SUMS.txt'
        Invoke-SoundLiftDownload ([string]$installerAsset.browser_download_url) $installerPath $progressBar $statusText 0 92 'Telepítő letöltése'
        Invoke-SoundLiftDownload ([string]$checksumAsset.browser_download_url) $checksumPath $progressBar $statusText 92 8 'Ellenőrzőösszeg letöltése'
        $progressBar.Value = 100; $progressBar.IsIndeterminate = $true; $statusText.Text = 'Telepítő biztonsági ellenőrzése…'; [Windows.Forms.Application]::DoEvents()
        $checksumLine = Get-Content -LiteralPath $checksumPath | Where-Object { $_ -match '(?i)^[a-f0-9]{64}\s+\*?SoundLift[ .]Setup\.exe$' } | Select-Object -First 1
        if (-not $checksumLine) { throw 'A telepítő ellenőrzőösszege nem található.' }
        $expectedHash = ([regex]::Match($checksumLine, '(?i)^[a-f0-9]{64}')).Value.ToLowerInvariant()
        $actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) { throw 'A letöltött telepítő ellenőrzése sikertelen.' }
        Save-SoundLiftRollbackCopy
        $statusText.Text = 'Telepítés folyamatban… A SoundLift hamarosan bezárul.'; [Windows.Forms.Application]::DoEvents()
        $pendingState = @{ from_version=$script:appVersion; target_version=[string]$latestVersion; started_utc=[DateTime]::UtcNow.ToString('o') }
        [IO.File]::WriteAllText($updateStatePath, ($pendingState | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
        Write-SoundLiftLog -Category update -EventName 'download_page_opened' -Data @{ old_version=$script:appVersion; new_version=$latestVersion; result='automatic_installer_started' }
        [void](Send-SoundLiftPendingLogs)
        # A telepítő nem írhatja felül megbízhatóan a futó SoundLift.exe fájlt.
        # Ezért külön, rejtett Windows PowerShell folyamat várja meg a jelenlegi
        # példány teljes leállását, telepít, majd kizárólag az új EXE-t indítja el.
        $helperPath = Join-Path $temporaryDirectory 'install-update.ps1'
        $escapedInstallerPath = $installerPath.Replace("'", "''")
        $escapedLaunchPath = $script:appLaunchPath.Replace("'", "''")
        $currentProcessId = [Diagnostics.Process]::GetCurrentProcess().Id
        $helperSource = @"
`$ErrorActionPreference = 'Stop'
`$installerPath = '$escapedInstallerPath'
`$applicationPath = '$escapedLaunchPath'
`$soundLiftProcessId = $currentProcessId
try { Wait-Process -Id `$soundLiftProcessId -ErrorAction SilentlyContinue } catch { }
`$installerProcess = Start-Process -FilePath `$installerPath -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CLOSEAPPLICATIONS') -Wait -PassThru
if (`$installerProcess.ExitCode -notin @(0, 3010)) { exit `$installerProcess.ExitCode }
Start-Sleep -Milliseconds 800
if (-not (Test-Path -LiteralPath `$applicationPath)) { exit 2 }
Start-Process -FilePath `$applicationPath
"@
        [IO.File]::WriteAllText($helperPath, $helperSource, [Text.UTF8Encoding]::new($true))
        $windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $windowsPowerShell)) { throw 'A Windows PowerShell nem található a frissítés telepítéséhez.' }
        $helperArguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$helperPath`""
        Start-Process -FilePath $windowsPowerShell -ArgumentList $helperArguments -WindowStyle Hidden -ErrorAction Stop
        return $true
    } catch {
        Write-SoundLiftLog -Category update -EventName 'update_check_failed' -Severity error -ErrorRecord $_ -Data @{ new_version=$latestVersion; stage='automatic_install' }
        $statusText.Text = "A frissítés sikertelen: $($_.Exception.Message)"
        $installButton.Content = 'Újrapróbálás'; $installButton.IsEnabled = $true
        $progressBar.IsIndeterminate = $false; $progressBar.Value = 0
        if (Test-Path $updateStatePath) { Remove-Item -LiteralPath $updateStatePath -Force -ErrorAction SilentlyContinue }
        if ($temporaryDirectory -and (Test-Path $temporaryDirectory)) { try { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force } catch { } }
        return $false
    }
}

function Show-AppUpdateDialog([object]$release, [version]$latestVersion) {
    $dialog=[Windows.Window]::new(); $dialog.Title='SoundLift – Frissítés'; $dialog.Width=550; $dialog.Height=345
    $dialog.ResizeMode='NoResize'; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Owner=$window; Set-SoundLiftWindowStyle $dialog
    $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(28)
    $title=[Windows.Controls.TextBlock]::new(); $title.Text='Új SoundLift-frissítés érhető el'; $title.FontSize=23; $title.FontWeight='Bold'; $title.Foreground='#FF4057'
    $details=[Windows.Controls.TextBlock]::new(); $details.Text="Telepített verzió: $script:appVersion`nÚj verzió: $latestVersion"; $details.FontSize=14; $details.Margin=[Windows.Thickness]::new(0,16,0,14)
    $status=[Windows.Controls.TextBlock]::new(); $status.Text='A frissítés automatikusan letöltődik és települ.'; $status.TextWrapping='Wrap'; $status.Foreground='#CBD5E1'; $status.Margin=[Windows.Thickness]::new(0,0,0,18)
    $progress=[Windows.Controls.ProgressBar]::new(); $progress.Height=9; $progress.Minimum=0; $progress.Maximum=100; $progress.Value=0; $progress.Visibility='Collapsed'; $progress.Margin=[Windows.Thickness]::new(0,0,0,20); $progress.Foreground=$window.Resources['AccentTextBrush']; $progress.Background='#242429'
    $buttons=[Windows.Controls.StackPanel]::new(); $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'
    $later=[Windows.Controls.Button]::new(); $later.Content='Később'; $later.Width=100; $later.Margin=[Windows.Thickness]::new(0,0,10,0)
    $install=[Windows.Controls.Button]::new(); $install.Content='Frissítés telepítése'; $install.Width=175
    $later.Add_Click({ $dialog.Close() }.GetNewClosure())
    $install.Add_Click({
        if (Install-SoundLiftUpdate $release $latestVersion $status $install $progress) {
            $dialog.Close(); $script:reallyExit=$true; $window.Close()
        }
    }.GetNewClosure())
    $buttons.Children.Add($later)|Out-Null; $buttons.Children.Add($install)|Out-Null
    foreach($control in @($title,$details,$status,$progress,$buttons)){ $panel.Children.Add($control)|Out-Null }
    $dialog.Content=$panel; $dialog.ShowDialog()|Out-Null
}

function Check-AppUpdate {
    param([switch]$Silent)
    Write-SoundLiftLog -Category update -EventName 'update_check_started'
    try {
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/Idkbroo1763/SoundLift/releases/latest' -Headers @{ 'User-Agent'="SoundLift/$($script:appVersion)"; 'Accept'='application/vnd.github+json' } -TimeoutSec 12
        $latestVersion = [version](([string]$release.tag_name).Trim().TrimStart([char[]]'vV'))
        $currentVersion = [version]$script:appVersion
        if ($latestVersion -gt $currentVersion) {
            Write-SoundLiftLog -Category update -EventName 'update_available' -Data @{ old_version=$currentVersion; new_version=$latestVersion }
            Show-AppUpdateDialog $release $latestVersion
        } elseif (-not $Silent) {
            Write-SoundLiftLog -Category update -EventName 'update_check_succeeded' -Data @{ result='up_to_date'; current_version=$currentVersion }
            Show-SoundLiftMessage "A program naprakész.`nTelepített verzió: $currentVersion" 'SoundLift – Frissítés' 'OK' 'Information' $window | Out-Null
        } else { Write-SoundLiftLog -Category update -EventName 'update_check_succeeded' -Data @{ result='up_to_date'; current_version=$currentVersion } }
    } catch {
        Write-SoundLiftLog -Category update -EventName 'update_check_failed' -Severity warning -ErrorRecord $_
        if (-not $Silent) { Show-SoundLiftMessage "A frissítés most nem ellenőrizhető.`n`n$($_.Exception.Message)" 'SoundLift – Frissítés' 'OK' 'Warning' $window | Out-Null }
    }
}

function Start-AsyncAppUpdateCheck {
    try {
        $script:updateCheckClient = [Net.WebClient]::new()
        $script:updateCheckClient.Headers['User-Agent'] = "SoundLift/$($script:appVersion)"
        $script:updateCheckClient.Headers['Accept'] = 'application/vnd.github+json'
        $script:updateCheckClient.Add_DownloadStringCompleted({
            param($sender, $eventArgs)
            try {
                if ($eventArgs.Cancelled -or $eventArgs.Error) { throw $(if ($eventArgs.Error) { $eventArgs.Error } else { 'A frissítésellenőrzés megszakadt.' }) }
                $release = $eventArgs.Result | ConvertFrom-Json
                $latestVersion = [version](([string]$release.tag_name).Trim().TrimStart([char[]]'vV'))
                if ($latestVersion -gt [version]$script:appVersion) {
                    Write-SoundLiftLog -Category update -EventName 'update_available' -Data @{ old_version=$script:appVersion; new_version=$latestVersion }
                    if ($script:doNotDisturb -or -not $window.IsActive -or -not $window.IsVisible) {
                        $StatusText.Text = "Új frissítés érhető el: V$latestVersion"
                        if (-not $script:doNotDisturb) { $script:trayIcon.ShowBalloonTip(3500, 'SoundLift-frissítés érhető el', "Új verzió: V$latestVersion. Nyisd meg a SoundLiftet a telepítéshez.", [Windows.Forms.ToolTipIcon]::Info) }
                    } else {
                        Show-AppUpdateDialog $release $latestVersion
                    }
                } else {
                    Write-SoundLiftLog -Category update -EventName 'update_check_succeeded' -Data @{ result='up_to_date'; current_version=$script:appVersion }
                }
            } catch {
                Write-SoundLiftLog -Category update -EventName 'update_check_failed' -Severity warning -Data @{ stage='background_check' } -ErrorRecord $_
            } finally {
                if ($sender) { $sender.Dispose() }
                $script:updateCheckClient = $null
            }
        })
        $script:updateCheckClient.DownloadStringAsync([Uri]'https://api.github.com/repos/Idkbroo1763/SoundLift/releases/latest')
    } catch {
        Write-SoundLiftLog -Category update -EventName 'update_check_failed' -Severity warning -Data @{ stage='background_start' } -ErrorRecord $_
    }
}
$UpdateButton.Add_Click({ Check-AppUpdate })

function Show-PostUpdateResult {
    if (-not (Test-Path $updateStatePath)) { return }
    try {
        $state = Get-Content -LiteralPath $updateStatePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $targetVersion = [version]([string]$state.target_version)
        $currentVersion = [version]$script:appVersion
        if ($currentVersion -lt $targetVersion) { return }
        Remove-Item -LiteralPath $updateStatePath -Force -ErrorAction SilentlyContinue
        Write-SoundLiftLog -Category update -EventName 'automatic_update_verified' -Data @{ old_version=$state.from_version; new_version=$script:appVersion; result='success' }

        $dialog=[Windows.Window]::new(); $dialog.Title='SoundLift – Frissítés kész'; $dialog.Width=500; $dialog.Height=245
        $dialog.ResizeMode='NoResize'; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Owner=$window; Set-SoundLiftWindowStyle $dialog
        $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(28)
        $title=[Windows.Controls.TextBlock]::new(); $title.Text='✓  A frissítés sikeresen települt'; $title.FontSize=22; $title.FontWeight='Bold'; $title.Foreground='#4ADE80'
        $details=[Windows.Controls.TextBlock]::new(); $details.Text="A SoundLift most már a V$script:appVersion verziót használja.`nMinden beállításod megmaradt."; $details.FontSize=14; $details.LineHeight=22; $details.Margin=[Windows.Thickness]::new(0,18,0,22); $details.Foreground='#CBD5E1'
        $close=[Windows.Controls.Button]::new(); $close.Content='Rendben'; $close.Width=120; $close.HorizontalAlignment='Right'; $close.Style=$window.Resources['PrimaryButton']; $close.Add_Click({$dialog.Close()}.GetNewClosure())
        $panel.Children.Add($title)|Out-Null; $panel.Children.Add($details)|Out-Null; $panel.Children.Add($close)|Out-Null
        $dialog.Content=$panel; $dialog.ShowDialog()|Out-Null
    } catch {
        Remove-Item -LiteralPath $updateStatePath -Force -ErrorAction SilentlyContinue
        Write-SoundLiftLog -Category update -EventName 'automatic_update_verification_failed' -Severity warning -ErrorRecord $_
    }
}

function Show-AboutWindow {
    $dialog = [Windows.Window]::new()
    $dialog.Title = 'Névjegy – SoundLift'; $dialog.Width = 620; $dialog.Height = 535
    $dialog.ResizeMode = 'NoResize'; $dialog.WindowStartupLocation = 'CenterOwner'; $dialog.Owner = $window
    Set-SoundLiftWindowStyle $dialog
    if (Test-Path $appIconPath) { try { $dialog.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$appIconPath) } catch { } }

    $root = [Windows.Controls.Grid]::new(); $root.Margin = [Windows.Thickness]::new(28)
    $root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
    $actionsRow = [Windows.Controls.RowDefinition]::new(); $actionsRow.Height = [Windows.GridLength]::Auto; $root.RowDefinitions.Add($actionsRow)
    $card = [Windows.Controls.Border]::new(); $card.CornerRadius = [Windows.CornerRadius]::new(18); $card.Padding = [Windows.Thickness]::new(24)
    $card.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#111113'))
    $card.BorderBrush = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#29292E')); $card.BorderThickness = [Windows.Thickness]::new(1)
    $content = [Windows.Controls.StackPanel]::new()
    $brand = [Windows.Controls.TextBlock]::new(); $brand.Text = 'SOUNDLIFT'; $brand.FontSize = 29; $brand.FontWeight = 'Bold'; $brand.Foreground = $window.Resources['AccentTextBrush']
    $version = [Windows.Controls.TextBlock]::new(); $version.Text = "Windows rendszerhang-kezelő  •  V$script:appVersion"; $version.FontSize = 12; $version.Foreground = [Windows.Media.Brushes]::Gray; $version.Margin = [Windows.Thickness]::new(0,5,0,20)
    $description = [Windows.Controls.TextBlock]::new(); $description.Text = 'A SoundLift egy modern Windows-hangvezérlő. Hangprofilokat, mélyhangkiemelést, tízsávos hangszínszabályzót és akár 300%-os hangerő-erősítést biztosít az Equalizer APO segítségével.'; $description.TextWrapping = 'Wrap'; $description.FontSize = 14; $description.LineHeight = 22; $description.Foreground = [Windows.Media.Brushes]::LightGray
    $creator = [Windows.Controls.TextBlock]::new(); $creator.Text = "Készítette: ɪᴅᴋʙʀᴏᴏ`nDiscord: idkbroo_6"; $creator.FontSize = 14; $creator.FontWeight = 'SemiBold'; $creator.Foreground = [Windows.Media.Brushes]::White; $creator.Margin = [Windows.Thickness]::new(0,22,0,18)
    $copyright = [Windows.Controls.TextBlock]::new(); $copyright.Text = '© 2026 idkbroo. Minden jog fenntartva. A SoundLift független projekt; az Equalizer APO neve és jogai a saját tulajdonosait illetik. A túl magas hangerő halláskárosodást okozhat.'; $copyright.TextWrapping = 'Wrap'; $copyright.FontSize = 11; $copyright.LineHeight = 17; $copyright.Foreground = [Windows.Media.Brushes]::Gray
    $content.Children.Add($brand) | Out-Null; $content.Children.Add($version) | Out-Null; $content.Children.Add($description) | Out-Null; $content.Children.Add($creator) | Out-Null; $content.Children.Add($copyright) | Out-Null
    $card.Child = $content; [Windows.Controls.Grid]::SetRow($card, 0); $root.Children.Add($card) | Out-Null

    $actions = [Windows.Controls.Grid]::new(); $actions.Margin = [Windows.Thickness]::new(0,14,0,0)
    $actions.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new()); $actions.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $discordButton = [Windows.Controls.Button]::new(); $discordButton.Content = 'Csatlakozás a Discord-szerverhez'; $discordButton.Height = 46; $discordButton.Margin = [Windows.Thickness]::new(0,0,8,0); $discordButton.Style = $window.Resources['PrimaryButton']
    $closeButton = [Windows.Controls.Button]::new(); $closeButton.Content = 'Bezárás'; $closeButton.Height = 46; $closeButton.Margin = [Windows.Thickness]::new(8,0,0,0); $closeButton.Style = $window.Resources['UtilityButton']
    $discordButton.Add_Click({ try { Start-Process 'https://discord.gg/h9CaQ47gDT' } catch { Show-SoundLiftMessage 'A Discord-link nem nyitható meg.' 'Névjegy' 'OK' 'Warning' $dialog | Out-Null } })
    $closeButton.Add_Click({ $dialog.Close() }.GetNewClosure())
    $actions.Children.Add($discordButton) | Out-Null; [Windows.Controls.Grid]::SetColumn($closeButton, 1); $actions.Children.Add($closeButton) | Out-Null
    [Windows.Controls.Grid]::SetRow($actions, 1); $root.Children.Add($actions) | Out-Null
    $dialog.Content = $root; $dialog.ShowDialog() | Out-Null
}
$AboutButton.Add_Click({ Show-AboutWindow })

function Show-PrivacyWindow {
    $dialog=[Windows.Window]::new(); $dialog.Title='SoundLift – Adatvédelmi tájékoztató'; $dialog.Width=720; $dialog.Height=650; $dialog.MinWidth=620; $dialog.MinHeight=480
    $dialog.WindowStartupLocation='CenterOwner'; $dialog.Owner=$window; Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.Grid]::new(); $root.Margin=[Windows.Thickness]::new(24)
    $root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new()); $buttonRow=[Windows.Controls.RowDefinition]::new(); $buttonRow.Height=[Windows.GridLength]::Auto; $root.RowDefinitions.Add($buttonRow)
    $scroll=[Windows.Controls.ScrollViewer]::new(); $scroll.VerticalScrollBarVisibility='Auto'; $scroll.HorizontalScrollBarVisibility='Disabled'
    $panel=[Windows.Controls.StackPanel]::new(); $panel.Margin=[Windows.Thickness]::new(4,0,12,0)
    $title=[Windows.Controls.TextBlock]::new(); $title.Text='Adatvédelmi tájékoztató'; $title.FontSize=25; $title.FontWeight='Bold'; $title.Foreground=$window.Resources['AccentTextBrush']; $title.Margin=[Windows.Thickness]::new(0,0,0,16)
    $body=[Windows.Controls.TextBlock]::new(); $body.Text=@"
MIT KÜLDHET AUTOMATIKUSAN A SOUNDLIFT?
• alkalmazásverzió, időpont, eseménytípus és súlyosság;
• véletlenszerű telepítési azonosító és rövid támogatási ID;
• licenctípus és termékazonosító, de a licenckulcs nem;
• az összekapcsolt Discord-fiók felhasználói azonosítója és megjelenített neve;
• technikai hibaüzenet, kivételtípus és a hibát okozó kódrész helye;
• frissítésnél a régi és új verzió, a folyamat állapota és eredménye.

MIT KÜLD A „HIBA JELENTÉSE” FUNKCIÓ?
Csak az Elküldés megnyomása után továbbítja az előnézetben látható adatokat: az opcionális saját leírást, támogatási ID-t, Windows-verziót, aktív hangkimenet nevét, rendszergazdai állapotot, az Equalizer APO és a SoundLift konfigurációjának állapotát, valamint az ismert ütköző hangprogramok folyamatnevét.

MIT NEM KÜLDÜNK?
• nyers licenckulcsot, jelszót, Discord tokent vagy webhookot;
• Windows-felhasználónevet és teljes felhasználói mappaútvonalat;
• teljes gép- vagy hardverazonosítót;
• Discord-üzeneteket, szerverlistát vagy böngészési előzményeket;
• személyes fájlokat és azok tartalmát.

OPCIONÁLIS DISCORD ZENEÁLLAPOT
Bekapcsolásakor a SoundLift a Spotify ablakcíméből helyben kiolvassa az aktuális szám megjelenített címét, és közvetlenül a számítógépen futó Discord kliensnek adja át állapotmegjelenítéshez. A szám címe nem kerül a SoundLift kiszolgálójára, technikai naplóiba vagy hibajelentéseibe. Kikapcsoláskor a SoundLift törli a saját Discord-aktivitását.

TÁROLÁS ÉS BIZTONSÁG
A helyi technikai naplók a %LOCALAPPDATA%\SoundLift\logs mappában találhatók, és 14 nap után automatikusan törlődnek. A sikertelenül továbbított események titkos adat nélkül várólistára kerülnek, majd a következő indításkor újrapróbáljuk őket. A továbbított naplók a SoundLift támogatási rendszerében addig maradnak meg, amíg hibakeresési vagy biztonsági célból szükségesek.

KAPCSOLAT
Adatvédelmi vagy törlési kéréshez használd a Névjegy és Discord menüben található SoundLift Discord-szervert, és add meg a támogatási ID-dat.
"@; $body.TextWrapping='Wrap'; $body.FontSize=13; $body.LineHeight=20; $body.Foreground='#CBD5E1'
    $panel.Children.Add($title)|Out-Null; $panel.Children.Add($body)|Out-Null; $scroll.Content=$panel; $root.Children.Add($scroll)|Out-Null
    $close=[Windows.Controls.Button]::new(); $close.Content='Rendben'; $close.Width=120; $close.HorizontalAlignment='Right'; $close.Margin=[Windows.Thickness]::new(0,14,0,0); $close.Style=$window.Resources['PrimaryButton']; $close.Add_Click({$dialog.Close()}.GetNewClosure())
    [Windows.Controls.Grid]::SetRow($close,1); $root.Children.Add($close)|Out-Null; $dialog.Content=$root; $dialog.ShowDialog()|Out-Null
}
$PrivacyButton.Add_Click({ Show-PrivacyWindow })

function Show-ChangelogWindow {
    $changelog = @"
V1.6.0 – BEÁLLÍTÓVARÁZSLÓ, AUTOMATIKUS JAVÍTÁS ÉS LICENCKEZELŐ
• Az első indítás varázslója ellenőrzi és javítja az APO-kapcsolatot, megnyitja a hangeszközválasztót, hangtesztet futtat és kezdőprofilt alkalmaz.
• Az automatikus javítás felismeri a hiányzó Include sort, valamint a hiányzó, sérült vagy olvashatatlan SoundLift-konfigurációt, és biztonsági mentéssel állítja helyre.
• A javítás sikerét vagy rövid hibakódját külön technikai esemény naplózza.
• Az új licenckezelő mutatja a licenc típusát, állapotát, gépkötését és az engedélyezett egyedi funkciókat.
• A gépcsere közvetlenül az alkalmazásból kérelmezhető, a jelenlegi gép az adminisztrátori jóváhagyásig használható marad.

V1.5.1 – RÉSZLETES, TAKARÉKOS LICENCNAPLÓZÁS
• A licencnapló mutatja a licenc típusát, állapotát, buildjét, gépkötését és az engedélyezett egyedi funkciókat.
• A gépcsere, a visszavont vagy tiltott licenc és az offline ellenőrzés külön, egyértelmű eseményként jelenik meg.
• A normál online ellenőrzések naponta egyszer kerülnek a Discord-naplóba, így nem fogyasztják feleslegesen a Supabase- és webhook-keretet.

V1.5.0 – TELJES FELÜLETI MEGÚJULÁS
• A főablak tágasabb, egységesebb kártyákat, mezőket és állapotjelzést kapott.
• Minden SoundLift-ablak automatikusan a kiválasztott téma színeit használja.
• A régi Windows-üzenetdobozokat modern, saját SoundLift-párbeszédablakok váltották fel.
• A hosszabb üzenetek tördelve jelennek meg, a gombok és szövegek pedig minden témában kontrasztosak és olvashatók.

V1.4.2 – AUTOMATIKUS INDÍTÁS ÉS TELJES MAGYARÍTÁS
• A Windowszal történő automatikus indítás mostantól megbízható, emelt jogosultságú ütemezett feladatot használ.
• A kezelőfelület angol és félrefordított szövegei természetes magyar megfogalmazást kaptak.
• Egyértelműbbek lettek a Discord-állapot, a hanghatások, a jelszint és a fejlesztői eszközök feliratai.

V1.4.0 – MIKROFON, ÉJSZAKAI MÓD ÉS FEJLESZTŐI ESZKÖZÖK
• Új mikrofonpanel hangerőszabályzással, teszttel és illesztőprogram-függő javítási lehetőségekkel.
• Elkészült az Éjszakai mód és a kapcsolható profilváltási jelzés.
• A Discord-állapot megjelenítése már zene nélkül is mutatja az aktív SoundLift-profilt.
• Helyi használati statisztikák készülnek használati idővel, profilváltásokkal és torzítási jelzésekkel.
• A Fejlesztői konzol kizárólag érvényes fejlesztői licenccel látható és nyitható meg.

V1.3.27 – SYSTEM TRAY IKON JAVÍTÁSA
• A valódi értesítési területi ikon már a SoundLift indulásakor azonnal létrejön.
• Az X gomb csak elrejti a főablakot; a tray ikon és a gyorsmenü aktív marad.
• Dupla kattintással az ablak biztosan visszaáll és előtérbe kerül.
• A tray ikon kizárólag a Kilépés menüpont használatakor kerül eltávolításra.

V1.3.26 – PROFILRENDEZŐ ABLAK JAVÍTÁSA
• A Fel, Le és Elrejtés / mutatás gombok most teljes méretben, jól láthatóan elférnek az ablakban.
• A profillista és az alsó műveleti gombok közötti térköz rendezettebb lett.

V1.3.25 – RENDEZHETŐ PROFILOK ÉS ALKALMAZÁSHANGERŐ
• A profilok sorrendje külön szerkesztőben módosítható, a nem használt profilok elrejthetők.
• A Zene profil biztonságosan mindig a lista tetején marad.
• Az alkalmazásonkénti hangerőkeverő az appból és a tálcaikon gyorsmenüjéből is megnyitható.

V1.3.24 – TÁLCA-GYORSMENÜ ÉS ÉLŐ HANGMÉRŐ
• A tálcaikon jobb klikkes menüjéből állítható a hangerő, a profil, a némítás és a SoundLift-hatások kikapcsolása.
• A gyorsmenüből megnyitható a Windows hangkimenet-választó és az Equalizer APO eszközbeállítása.
• Az új élő sztereó hangmérő külön mutatja a bal és jobb csatorna jelszintjét, az aktuális boostot és a clippinget.

V1.3.23 – SZÖVEGJAVÍTÁS
• Az automatikus indítás beállításának helyes szövege mostantól: „Automatikus indítás a Windowssal”.

V1.3.22 – TELJESEN SZABAD GYORSBILLENTYŰK
• A profilok most már önálló betűhöz, számhoz, írásjelhez és egyéb használható billentyűhöz is rendelhetők.
• A számok D1 helyett olvashatóan 1 formában jelennek meg.
• Minden sor külön törlőgombot kapott, így a Backspace, Delete és Escape is használható gyorsbillentyűként.
• Az önálló billentyűk mentése előtt a SoundLift figyelmeztet, hogy gépelés közben is aktiválhatják a profilt.

V1.3.21 – DISCORD ZENEÁLLAPOT
• A bekapcsolható Discord-állapot megjeleníti a Spotify aktuális számát és az aktív hangprofilt.
• A számadat kizárólag a helyi Discord asztali klienshez kerül; a SoundLift kiszolgálója és naplózása nem kapja meg.
• A jelenlét automatikusan frissül szám- vagy profilváltáskor, Spotify leállításakor pedig törlődik.
• A funkció alapból kikapcsolt, és a Védelem és automatizálás résznél engedélyezhető.

V1.3.20 – TELJES BILLENTYŰPARANCS-SZERKESZTŐ
• A profilok és a gyors némítás tetszőleges biztonságos billentyűkombinációhoz rendelhető.
• A kívánt kombináció közvetlen lenyomással rögzíthető; az F1–F24 billentyűk önmagukban is használhatók.
• A Backspace kikapcsol egy parancsot, az ütköző és veszélyes rendszerkombinációkat a SoundLift elutasítja.
• A korábbi Ctrl+Alt+szám beállítások frissítés után automatikusan megmaradnak.

V1.3.19 – LICENCMEZŐ VÉGLEGES JAVÍTÁSA
• A licencmező már nem ütközik a PowerShell beépített input változójával.
• Az aktiválógomb biztosan a képernyőn beillesztett kulcsot olvassa ki.

V1.3.18 – LICENCKULCS BEILLESZTÉSÉNEK JAVÍTÁSA
• A SoundLift automatikusan felismeri az SL-kulcsot a PowerShellből kimásolt teljes sorban is.
• A címkék, idézőjelek, sortörések és rejtett másolási karakterek nem akadályozzák az aktiválást.

V1.3.17 – LICENCAKTIVÁLÁS JAVÍTÁSA
• A licencablak aktiválógombja megbízhatóan lezárja az adatbevitelt és elindítja az ellenőrzést.
• Hibás vagy hiányos kulcsnál az ablakban azonnal érthető visszajelzés jelenik meg.
• Az Enter billentyűvel is elindítható az aktiválás, az ablak pedig mindig a SoundLift előtt marad.

V1.3.16 – EGYEDI FUNKCIÓK, EGY KÖZÖS BUILD
• A kiszolgáló licencenként több egyedi funkciót oszthat ki ugyanahhoz a hivatalos alkalmazáshoz.
• Az Extra mélyhang Pro, a Beszédkiemelés és az Egyéni profil X csak a jogosult licencnél jelenik meg.
• Külön tulajdonosi tesztmód szimulálhat egy kiválasztott licencet a vásárló Discord-fiókjába belépés nélkül.
• A licenc és a kapcsolt Discord-fiók azonosságát a kiszolgáló most már kötelezően összeveti.
• A korábbi normál licencek extra funkció nélkül, változatlanul tovább működnek.

V1.3.15 – GYORSVEZÉRLÉS
• Gyors némítás és visszakapcsolás a tálcáról vagy globális billentyűparanccsal.
• Kereshető, egyszerűbb gyorsprofil-menü a tálcaikonban.
• Beépített súgóbuborékok magyarázzák a fontos vezérlőket.
• A profilváltó és némító billentyűparancsok szerkeszthetők, az ütközéseket az app ellenőrzi.
• A Ne zavarjanak mód elrejti a profilváltási és automatikus frissítési felugrókat.

V1.3.14 – RENDEZETT ESZKÖZTÁR
• A profilkezelés, a hangrendszer és a támogatási funkciók külön, áttekinthető csoportba kerültek.
• A műveleti gombok egységes szélességű, rendezett sorokban jelennek meg.
• Rövid magyarázat segíti az egyes eszközcsoportok használatát.
• Az indításkori ellenőrzések nem fagyasztják le a kezelőfelületet.

V1.3.13 – OFFLINE MÓD ÉS BIZTONSÁG
• Korábban ellenőrzött telepítés internetkimaradáskor legfeljebb 30 napig használható.
• Új Biztonságos mód kapcsolja ki a SoundLift hatásait és állítja vissza az eredeti hangot.
• Az eltávolító kitakarítja a SoundLift APO-kapcsolatát, fájljait és helyi alkalmazásadatait.
• Az automatikus tesztek ellenőrzik az offline határt, a biztonságos módot és a tiszta eltávolítást.

V1.3.12 – TÉMAVÁLASZTÓ EGYSZERŰSÍTÉSE
• A világos megjelenés teljesen kikerült az alkalmazásból.
• A korábban világos témát használóknál automatikusan a Fekete és piros téma töltődik be.
• A GitHub Actions futásneve mostantól mindig az aktuális verziót mutatja.

V1.3.11 – VILÁGOS MÓD ÉS KARAKTERKÓDOLÁS
• A világos témában minden normál gomb sötét, jól olvasható feliratot kap.
• A kiemelt gombok felirata továbbra is megfelelő kontrasztú.
• A Discord-jelentések magyar ékezeteinek automatikus helyreállítása.

V1.3.10 – KONTRASZT ÉS DISCORD-KÜLDÉS
• A gombok, jelölőnégyzetek és témaválasztó saját kontrasztos szövegsablont kaptak világos módban.
• A kiszolgáló külön visszajelzi, hogy a jelentés valóban eljutott-e a Discord hibanaplójába.
• Átmeneti Discord-hibánál a jelentés a küldési sorban marad és újrapróbálható.

V1.3.9 – VILÁGOS MÓD ÉS HIBAJELENTÉS
• A világos módban a címsorok, gombfeliratok, jelölőnégyzetek és témaválasztó szövege megfelelő kontrasztot kap.
• A kliens csak akkor jelez sikeres hibajelentést, ha a szerver legalább egy eseményt elfogadott.
• A kézi hibajelentéseket a kiszolgáló már külön támogatja és a hibanapló-csatornához továbbítja.

V1.3.8 – REJTETT PROFILGÖRGETÉS
• A hangprofilok továbbra is görgethetők egérgörgővel és touchpaddal.
• A zavaró függőleges görgetősáv már nem látható.

V1.3.7 – HIBAJELENTÉS JAVÍTÁSA
• A hibajelentő most már a megfelelő alkalmazáshatókörből ellenőrzi a beépített szolgáltatáscímet.
• Megszűnt a téves „hibajelentő szolgáltatás nincs beállítva” figyelmeztetés.

V1.3.6 – FELÜLETI ÉS HIBAJELENTÉSI JAVÍTÁSOK
• A hangprofilok kisebb ablakban is görgethetők.
• A világos mód feliratai és vezérlői mindenhol olvashatók.
• A Hibajelentés ablak modernebb, és küldés előtt ellenőrzi a jelentés előkészítését.
• A Beállítások alkalmazása gomb teljes szövege elfér.
• Megújultak a hangerő-, basszus- és hangszínszabályzó csúszkák.

V1.3.5 – ÚJ MEGJELENÉSEK
• Hat új téma: Fekete és lila, Éjkék és türkiz, Grafit és narancs, Fekete és arany, OLED fekete és Világos.
• A világos és OLED megjelenés a teljes felület színeit egységesen módosítja.
• A korábbi témabeállítások és importált profilok továbbra is használhatók.

V1.3.4 – PROFILNEVEK ÉS VERZIÓZÁS JAVÍTÁSA
• A két FiveM-profil neve mostantól egyértelműen FiveM RP és FiveM PvP.
• Új verziószám biztosítja, hogy minden V1.3.3-telepítés érzékelje a frissítést.
• Hat új megjelenés: fekete–lila, éjkék–türkiz, grafit–narancs, fekete–arany, OLED és világos.
• A világos és OLED mód a teljes főfelület színeit, kártyáit, gombjait és szövegeit egységesen kezeli.

V1.3.3 – MEGBÍZHATÓSÁG ÉS HIBAJELENTÉS
• Egységesebb, közérthetőbb magyar felület és korszerűbb kezelőszövegek.
• Élő letöltési százalék és külön telepítési állapot a frissítőablakban.
• Újraindítás után ellenőrzi és visszajelzi a sikeresen telepített verziót.
• Egygombos, biztonsági mentést készítő Equalizer APO Include-javítás.
• Átlátható hibajelentés-előnézet: elküldés előtt pontosan látható minden továbbított adat.
• Opcionális felhasználói hibaleírás a támogatási jelentésekhez.
• Beépített, részletes adatvédelmi tájékoztató külön menüponttal.

V1.3.2 – AUTOMATIKUS FRISSÍTÉS JAVÍTÁSA
• A frissítő kezeli a GitHub által ponttal tárolt telepítőnevet.
• A telepítő és az ellenőrzőösszeg fájlneve mostantól egységes.
• A későbbi automatikus frissítések kompatibilisek maradnak a korábbi elnevezéssel is.
• A témaválasztó szövege minden állapotban jól olvasható, sötét felületen jelenik meg.

V1.3.1 – SÖTÉT FELÜLET ÉS SOUNDLIFT NÉVEGYSÉGESÍTÉS
• Fekete Windows-címsor és sötét alkalmazáskeret.
• A jobb oldali görgetősáv elrejtve; az egérgörgős navigáció továbbra is működik.
• A témaválasztó teljesen sötét, a kijelölés az aktív téma színét használja.
• Minden alkalmazás-, indító- és konfigurációs fájl egységesen SoundLift nevet kapott.

V1.3.0 – EGYSÉGES ALKALMAZÁS ÉS LICENC
• Ugyanaz a telepítő használható ingyenes, vásárlói és fejlesztői módban.
• A licenc az alkalmazásban aktiválható, és frissítés után is megmarad.
• A fejlesztői visszaállítás továbbra is kizárólag developer licenccel érhető el.

V1.2.2 – AUTOMATIKUS FRISSÍTÉS
• Indításkor automatikusan ellenőrzi a legújabb nyilvános kiadást.
• Egy gombnyomással letölti és elindítja az új telepítőt.
• Telepítés előtt SHA-256 ellenőrzéssel védi a letöltött fájlt.
• Látható és egy kattintással másolható támogatási azonosító.
• Részletes letöltési, ellenőrzési és telepítési állapot, hiba után újrapróbálással.
• Az automatikus frissítés előtt mentett, ellenőrzött előző verzió visszaállítható.

V1.2.0 – DISCORD-FIÓK ÖSSZEKAPCSOLÁS
• Kötelező, hitelesített Discord OAuth-kapcsolat az alkalmazás használatához.
• Frissítés után is megmaradó kapcsolat és 72 órás védelem rövid kiszolgálói kiesésre.
• A logokban rövid támogatási ID és a hitelesített Discord-felhasználó jelenik meg.
• Egyszer használható, 10 perc után lejáró összekapcsolási munkamenetek.

V1.1.0 – KÖZPONTI NAPLÓZÁS
• Helyi technikai naplók és következő indításkor újrapróbált hibajelentések.
• Indítási, összeomlási, frissítési, licenc- és biztonsági események.
• Fejlesztői tesztlicenc-hozzáférések külön naplózása.
• Biztonságos kiszolgálói továbbítás: nincs Discord-webhook vagy titkos kulcs a kliensben.

V1.0.1 – BIZTONSÁGI FRISSÍTÉS
• Frissítési hivatkozások átállítva az új hivatalos GitHub-címre.
• Biztonságosabb, méret- és értékkorlátos profilimportálás.
• A hangeszközválasztó csak az Equalizer APO ismert programjait indítja el.
• Rögzített buildfüggőségek és SHA-256 ellenőrzőösszeg a letöltésekhez.

V1.0.0 – ELSŐ NYILVÁNOS KIADÁS
• Modern, témázható Windows-felület.
• 0–300%-os hangerő-erősítés.
• Zene, FiveM, R6, Discord és Film profilok.
• Finomhangolt, kevésbé dobozos játék-, beszéd-, film- és basszusprofilok.
• Tízsávos equalizer, basszuskiemelés és torzításvédelem.
• Saját profil mentése, betöltése, importálása és exportálása.
• Automatikus profilváltás és globális gyorsbillentyűk.
• Első indítási varázsló és beépített diagnosztika.
• Automatikus frissítésellenőrzés és frissítési előzmények.
• Névjegy, közvetlen Discord-kapcsolat és részletes telepítési útmutató.
"@
    $dialog = [Windows.Window]::new()
    $dialog.Title = "SoundLift $script:appVersion – Frissítési előzmények"
    $dialog.Width = 720; $dialog.Height = 590; $dialog.MinWidth = 560; $dialog.MinHeight = 420
    $dialog.WindowStartupLocation = 'CenterOwner'; $dialog.Owner = $window
    Set-SoundLiftWindowStyle $dialog
    $grid = [Windows.Controls.Grid]::new(); $grid.Margin = [Windows.Thickness]::new(22)
    $grid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
    $buttonRow = [Windows.Controls.RowDefinition]::new(); $buttonRow.Height = [Windows.GridLength]::Auto; $grid.RowDefinitions.Add($buttonRow)
    $box = [Windows.Controls.TextBox]::new(); $box.Text = $changelog.Trim(); $box.IsReadOnly = $true; $box.AcceptsReturn = $true
    $box.TextWrapping = 'Wrap'; $box.VerticalScrollBarVisibility = 'Auto'; $box.FontSize = 14; $box.Padding = [Windows.Thickness]::new(16)
    $box.Background = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#111113'))
    $box.Foreground = [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString('#F8FAFC'))
    $box.BorderBrush = $window.Resources['AccentTextBrush']; [Windows.Controls.Grid]::SetRow($box, 0); $grid.Children.Add($box) | Out-Null
    $close = [Windows.Controls.Button]::new(); $close.Content = 'Bezárás'; $close.Width = 115; $close.Height = 38; $close.HorizontalAlignment = 'Right'; $close.Margin = [Windows.Thickness]::new(0,12,0,0)
    $close.Add_Click({ $dialog.Close() }.GetNewClosure()); [Windows.Controls.Grid]::SetRow($close, 1); $grid.Children.Add($close) | Out-Null
    $dialog.Content = $grid; $dialog.ShowDialog() | Out-Null
}
$ChangelogButton.Add_Click({ Show-ChangelogWindow })

function Show-FirstRunWizard {
    $wizard = [Windows.Window]::new()
    $wizard.Title = 'SoundLift – Első indítás'; $wizard.Width = 650; $wizard.Height = 470
    $wizard.ResizeMode = 'NoResize'; $wizard.WindowStartupLocation = 'CenterOwner'; $wizard.Owner = $window
    Set-SoundLiftWindowStyle $wizard
    $root = [Windows.Controls.Grid]::new(); $root.Margin = [Windows.Thickness]::new(28)
    $root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
    $navRow = [Windows.Controls.RowDefinition]::new(); $navRow.Height = [Windows.GridLength]::Auto; $root.RowDefinitions.Add($navRow)
    $content = [Windows.Controls.StackPanel]::new()
    $stepText = [Windows.Controls.TextBlock]::new(); $stepText.Foreground = [Windows.Media.Brushes]::Gray; $stepText.FontSize = 12
    $titleText = [Windows.Controls.TextBlock]::new(); $titleText.Foreground = [Windows.Media.Brushes]::White; $titleText.FontSize = 26; $titleText.FontWeight = 'Bold'; $titleText.Margin = [Windows.Thickness]::new(0,10,0,16)
    $bodyText = [Windows.Controls.TextBlock]::new(); $bodyText.Foreground = $window.Resources['SecondaryTextBrush']; $bodyText.FontSize = 15; $bodyText.LineHeight = 25; $bodyText.TextWrapping = 'Wrap'
    $actionButton = [Windows.Controls.Button]::new(); $actionButton.Width=260; $actionButton.Height=42; $actionButton.HorizontalAlignment='Left'; $actionButton.Margin=[Windows.Thickness]::new(0,18,0,0); $actionButton.Style=$window.Resources['UtilityButton']; $actionButton.Visibility='Collapsed'
    $profileChoice = [Windows.Controls.ComboBox]::new(); $profileChoice.Width=260; $profileChoice.Height=40; $profileChoice.HorizontalAlignment='Left'; $profileChoice.Margin=[Windows.Thickness]::new(0,18,0,0); $profileChoice.Visibility='Collapsed'
    foreach($profileName in @('Zene – ajánlott','FiveM RP','FiveM PvP','Rainbow Six Siege','Film','Alapbeállítások')){[void]$profileChoice.Items.Add($profileName)}; $profileChoice.SelectedIndex=0
    $content.Children.Add($stepText) | Out-Null; $content.Children.Add($titleText) | Out-Null; $content.Children.Add($bodyText) | Out-Null; $content.Children.Add($actionButton)|Out-Null; $content.Children.Add($profileChoice)|Out-Null
    [Windows.Controls.Grid]::SetRow($content, 0); $root.Children.Add($content) | Out-Null
    $nav = [Windows.Controls.StackPanel]::new(); $nav.Orientation = 'Horizontal'; $nav.HorizontalAlignment = 'Right'; $nav.Margin = [Windows.Thickness]::new(0,20,0,0)
    $back = [Windows.Controls.Button]::new(); $back.Content = 'Vissza'; $back.Width = 105; $back.Height = 38; $back.Margin = [Windows.Thickness]::new(0,0,10,0)
    $next = [Windows.Controls.Button]::new(); $next.Content = 'Tovább'; $next.Width = 125; $next.Height = 38
    $nav.Children.Add($back) | Out-Null; $nav.Children.Add($next) | Out-Null; [Windows.Controls.Grid]::SetRow($nav, 1); $root.Children.Add($nav) | Out-Null
    $apo = Get-ApoConfigDirectory; $output = [AudioAppNative]::GetDefaultOutputName()
    $adminState = if (Test-Administrator) { 'Rendben' } else { 'Nincs rendszergazdai jogosultság' }
    $apoState = if ($apo) { 'Telepítve' } else { 'Nem található' }
    $pages = @(
        @{ Title='Üdv a SoundLiftben!'; Body="Ez a rövid beállítás segít, hogy a hangerő- és EQ-profilok valóban a megfelelő hangeszközön működjenek.`n`nA program az Equalizer APO-ra épül, ezért annak telepítve kell lennie." },
        @{ Title='Gyors rendszerellenőrzés'; Body="Equalizer APO: $apoState`nRendszergazdai futtatás: $adminState`nAktív hangkimenet: $output`n`nA gomb ellenőrzi és szükség esetén biztonsági mentéssel javítja a SoundLift hangkapcsolatát."; Action='Ellenőrzés és automatikus javítás' },
        @{ Title='Hangeszköz kiválasztása'; Body="Nyisd meg az Equalizer APO hangeszközválasztóját, majd jelöld ki azt a lejátszóeszközt, amelyen a SoundLiftet használni szeretnéd.`n`nHa az APO újraindítást kér, a varázsló befejezése után indítsd újra a Windowst."; Action='Hangeszköz kiválasztása' },
        @{ Title='Hangteszt'; Body="A rövid, halk teszthanggal ellenőrizheted, hogy a kiválasztott hangkimenet működik-e.`n`nA teszt nem módosítja a beállításaidat."; Action='Teszt hang lejátszása' },
        @{ Title='Ajánlott kezdőprofil'; Body="Válassz egy kezdőprofilt. A Zene profil az ajánlott általános beállítás, és később bármikor lecserélheted.`n`nA Befejezés gomb alkalmazza és elmenti a választást."; Profile=$true }
    )
    $wizardState = @{ Page = 0 }
    $refreshPage = { $page = [int]$wizardState.Page; $current=$pages[$page]; $stepText.Text = "ELSŐ INDÍTÁS  •  $($page + 1) / $($pages.Count)"; $titleText.Text = $current.Title; $bodyText.Text = $current.Body; $back.IsEnabled = $page -gt 0; $next.Content = if ($page -eq $pages.Count - 1) { 'Befejezés' } else { 'Tovább' }; $actionButton.Visibility=if($current.Action){'Visible'}else{'Collapsed'}; if($current.Action){$actionButton.Content=$current.Action}; $profileChoice.Visibility=if($current.Profile){'Visible'}else{'Collapsed'} }
    $actionButton.Add_Click({ switch([int]$wizardState.Page){ 1 { [void](Repair-SoundLiftApoInclude -Automatic); $health=Get-SoundLiftApoHealth; $bodyText.Text="$($pages[1].Body)`n`nEredmény: $($health.Message) [$($health.Code)]" } 2 { Open-SoundLiftDeviceSelector } 3 { Play-TestTone 60 1.5 } } }.GetNewClosure())
    $back.Add_Click({ if ($wizardState.Page -gt 0) { $wizardState.Page--; & $refreshPage } }.GetNewClosure())
    $next.Add_Click({ if ($wizardState.Page -lt $pages.Count - 1) { $wizardState.Page++; & $refreshPage; return }; $profileButtons=@($MusicButton,$GameButton,$CombatButton,$R6Button,$MovieButton,$ResetButton); $selectedButton=$profileButtons[[Math]::Max(0,$profileChoice.SelectedIndex)]; $selectedButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))); Invoke-ApplyButton; try { [IO.File]::WriteAllText($onboardingMarkerPath, 'completed', [Text.Encoding]::UTF8); $script:onboardingCompleted=$true; $state = Get-AppState; $state.onboardingCompleted = $true; $state | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8 } catch { }; $wizard.Close() }.GetNewClosure())
    & $refreshPage; $wizard.Content = $root; $wizard.ShowDialog() | Out-Null
}

$SaveButton.Add_Click({
    (Get-AppState) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $customProfilePath -Encoding UTF8
    $StatusText.Text = 'Az egyéni profil mentése elkészült'
})
$LoadButton.Add_Click({
    if (Test-Path $customProfilePath) { Set-AppState (Get-Content -LiteralPath $customProfilePath -Raw | ConvertFrom-Json); $StatusText.Text = 'A mentett egyéni profil betöltve' }
})
$ExportButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'EQ profil (*.json)|*.json'; $dialog.FileName = 'sajat-hangprofil.json'
    if ($dialog.ShowDialog()) { (Get-AppState) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8 }
})

function Test-ImportedProfile($state) {
    if ($null -eq $state) { throw 'A profil üres vagy nem érvényes JSON-fájl.' }
    $names = @($state.PSObject.Properties.Name)
    foreach ($required in @('volume','bass','frequency','eq')) {
        if ($names -notcontains $required) { throw "Hiányzó profilmező: $required" }
    }

    $volume = [double]$state.volume; $bass = [double]$state.bass; $frequency = [double]$state.frequency
    if ([double]::IsNaN($volume) -or [double]::IsInfinity($volume) -or $volume -lt 0 -or $volume -gt 300) { throw 'A hangerő csak 0 és 300 között lehet.' }
    if ([double]::IsNaN($bass) -or [double]::IsInfinity($bass) -or $bass -lt 0 -or $bass -gt 24) { throw 'A basszus csak 0 és 24 dB között lehet.' }
    if ([double]::IsNaN($frequency) -or [double]::IsInfinity($frequency) -or $frequency -lt 40 -or $frequency -gt 160) { throw 'A frekvencia csak 40 és 160 Hz között lehet.' }
    if ($state.eq.Count -ne 10) { throw 'Az EQ-profilnak pontosan 10 sávot kell tartalmaznia.' }
    foreach ($value in $state.eq) {
        $gain = [double]$value
        if ([double]::IsNaN($gain) -or [double]::IsInfinity($gain) -or $gain -lt -12 -or $gain -gt 12) { throw 'Minden EQ-értéknek -12 és +12 dB között kell lennie.' }
    }
    $allowedThemes = @($script:themeNames) + @('Black & Red','Black & Blue','Graphite & Green')
    if ($state.theme -and $allowedThemes -notcontains [string]$state.theme) { throw 'Ismeretlen témabeállítás található a profilban.' }
}

$ImportButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = 'EQ profil (*.json)|*.json'
    if ($dialog.ShowDialog()) {
        try {
            $file = Get-Item -LiteralPath $dialog.FileName -ErrorAction Stop
            if ($file.Length -gt 65536) { throw 'A profilfájl túl nagy. A megengedett maximum 64 KB.' }
            $state = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            Test-ImportedProfile $state
            Set-AppState $state
            $StatusText.Text = 'A profil ellenőrzése és importálása sikerült'
        } catch {
            Show-SoundLiftMessage "A profil nem importálható:`n$($_.Exception.Message)" 'Érvénytelen profil' 'OK' 'Warning' $window | Out-Null
        }
    }
})
$ProfileManagerButton.Add_Click({
    $menu = [Windows.Controls.ContextMenu]::new()
    foreach ($entry in @(
        @('Egyéni profil mentése',$SaveButton),
        @('Mentett profil betöltése',$LoadButton),
        @('Profil exportálása',$ExportButton),
        @('Profil importálása',$ImportButton)
    )) {
        $item=[Windows.Controls.MenuItem]::new();$item.Header=$entry[0];$target=$entry[1]
        $item.Add_Click({$target.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))}.GetNewClosure())
        [void]$menu.Items.Add($item)
    }
    $menu.PlacementTarget=$ProfileManagerButton;$menu.Placement='Bottom';$menu.IsOpen=$true
})
$UndoButton.Add_Click({
    $apo = Get-ApoConfigDirectory
    if ($apo) {
        $own = Join-Path $apo 'SoundLift.txt'; $undo = "$own.undo"
        if (Test-Path $undo) { [IO.File]::Copy($undo, $own, $true); $StatusText.Text = 'Az előző hangbeállítás visszaállítva' }
    }
})

function Disable-SoundLiftEffects {
    $apo = Get-ApoConfigDirectory
    if (-not $apo) { throw 'Az Equalizer APO konfigurációs mappája nem található.' }
    $main = Join-Path $apo 'config.txt'
    if (-not (Test-Path $main)) { throw 'Az Equalizer APO config.txt fájlja nem található.' }
    $text = Read-TextWithRetry $main
    $text = [Regex]::Replace($text, '(?im)^\s*#\s*SoundLift\s*\r?\n\s*Include:[^\r\n]+\r?\n?', '')
    $text = [Regex]::Replace($text, '(?im)^\s*Include:\s*SoundLift\.txt\s*\r?\n?', '')
    Write-TextWithRetry $main ($text.TrimEnd() + "`r`n")
    if ((Read-TextWithRetry $main) -match '(?im)^\s*Include:\s*SoundLift\.txt\s*$') {
        throw 'A SoundLift kapcsolat kikapcsolása nem sikerült.'
    }
}

function Invoke-SoundLiftBypass([bool]$Confirm = $true) {
    if ($Confirm) {
        $answer = Show-SoundLiftMessage 'A biztonságos mód kikapcsolja a SoundLift összes hanghatását, és visszaállítja az Equalizer APO eredeti hangját. Folytatod?' 'SoundLift – Biztonságos mód' 'YesNo' 'Warning' $window
        if ($answer -ne 'Yes') { return }
    }
    try {
        Disable-SoundLiftEffects
        $script:isBypassed = $true
        $StatusText.Text = 'Biztonságos mód aktív • az eredeti hang visszaállítva'; $StatusBorder.Background = '#4A1F2D'
    } catch {
        Write-SoundLiftLog -Category crash -EventName 'handled_runtime_error' -Severity error -Data @{ component='safe_mode' } -ErrorRecord $_
        Show-SoundLiftMessage "A biztonságos mód nem kapcsolható be:`n$($_.Exception.Message)" 'SoundLift – hiba' 'OK' 'Error' $window | Out-Null
    }
}

function Disable-SoundLiftBypass {
    $script:isBypassed = $false
    Invoke-ApplyButton
}

$BypassButton.Add_Click({ Invoke-SoundLiftBypass $true })
function Open-SoundLiftDeviceSelector {
    $apoConfig = Get-ApoConfigDirectory
    $installDirectory = if ($apoConfig) { Split-Path $apoConfig -Parent } else { $null }
    $candidates = @()
    if ($installDirectory) {
        $candidates += Join-Path $installDirectory 'DeviceSelector.exe'
        $candidates += Join-Path $installDirectory 'Configurator.exe'
    }
    $selector = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if ($selector) {
        try {
            $selectorDirectory = [IO.Path]::GetDirectoryName([string]$selector)
            $platformDirectory = Join-Path $selectorDirectory 'platforms'
            $oldQtPlatformPath = $env:QT_QPA_PLATFORM_PLUGIN_PATH
            if (Test-Path $platformDirectory) {
                $env:QT_QPA_PLATFORM_PLUGIN_PATH = $platformDirectory
            }

            $startInfo = New-Object Diagnostics.ProcessStartInfo
            $startInfo.FileName = $selector
            $startInfo.WorkingDirectory = $selectorDirectory
            $startInfo.UseShellExecute = $true
            $startInfo.Verb = 'runas'
            [void][Diagnostics.Process]::Start($startInfo)

            $env:QT_QPA_PLATFORM_PLUGIN_PATH = $oldQtPlatformPath
        } catch {
            $env:QT_QPA_PLATFORM_PLUGIN_PATH = $oldQtPlatformPath
            Write-SoundLiftLog -Category crash -EventName 'handled_runtime_error' -Severity error -Data @{ component='device_selector' } -ErrorRecord $_
            Show-SoundLiftMessage "A hangeszközválasztó nem indítható el:`n$($_.Exception.Message)" 'Eszközök' 'OK' 'Error' $window | Out-Null
        }
    } else {
        Show-SoundLiftMessage 'Az Equalizer APO eszközválasztó nem található.' 'Eszközök' 'OK' 'Warning' $window | Out-Null
    }
}
$DeviceButton.Add_Click({ Open-SoundLiftDeviceSelector })

function Play-TestTone([int]$frequency = 60, [double]$seconds = 1.5) {
    $sampleRate = 44100; $samples = [int]($sampleRate * $seconds); $stream = New-Object IO.MemoryStream; $writer = New-Object IO.BinaryWriter($stream)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $writer.Write([int](36 + $samples * 2)); $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt ')); $writer.Write([int]16); $writer.Write([int16]1); $writer.Write([int16]1); $writer.Write([int]$sampleRate); $writer.Write([int]($sampleRate * 2)); $writer.Write([int16]2); $writer.Write([int16]16); $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([int]($samples * 2))
    for ($i = 0; $i -lt $samples; $i++) { $fade = [Math]::Min(1.0, [Math]::Min($i / 2205.0, ($samples - $i) / 2205.0)); $writer.Write([int16](7000 * $fade * [Math]::Sin(2 * [Math]::PI * $frequency * $i / $sampleRate))) }
    $stream.Position = 0; $player = New-Object Media.SoundPlayer($stream); $player.PlaySync(); $writer.Dispose(); $stream.Dispose()
}
$TestButton.Add_Click({ Play-TestTone 60 1.5 })

# Debounced instant mode prevents excessive disk writes while dragging.
$instantTimer = New-Object Windows.Threading.DispatcherTimer
$instantTimer.Interval = [TimeSpan]::FromMilliseconds(550)
$instantTimer.Add_Tick({ $instantTimer.Stop(); if ($InstantCheck.IsChecked) { Invoke-ApplyButton } })
$scheduleInstant = { if ($InstantCheck.IsChecked) { $instantTimer.Stop(); $instantTimer.Start() }; Update-Labels }
$VolumeSlider.Add_ValueChanged($scheduleInstant)
$BassSlider.Add_ValueChanged($scheduleInstant)
$FrequencySlider.Add_ValueChanged($scheduleInstant)
$SafetyCheck.Add_Click({ Update-Labels; if ($InstantCheck.IsChecked) { Invoke-ApplyButton } })
foreach ($eqSlider in $script:eqSliders) { $eqSlider.Add_ValueChanged($scheduleInstant) }

function Write-DiscordPresenceFrame([IO.Pipes.NamedPipeClientStream]$pipe, [int]$opcode, [hashtable]$payload) {
    $json = $payload | ConvertTo-Json -Depth 8 -Compress
    $body = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $header = New-Object byte[] 8
    [BitConverter]::GetBytes([int]$opcode).CopyTo($header, 0)
    [BitConverter]::GetBytes([int]$body.Length).CopyTo($header, 4)
    $pipe.Write($header, 0, $header.Length); $pipe.Write($body, 0, $body.Length); $pipe.Flush()
}

function Read-DiscordPresenceFrame([IO.Pipes.NamedPipeClientStream]$pipe) {
    $header = New-Object byte[] 8; $offset = 0
    while ($offset -lt 8) { $read=$pipe.Read($header,$offset,8-$offset); if($read -le 0){throw 'A Discord IPC-kapcsolat megszakadt.'};$offset+=$read }
    $length=[BitConverter]::ToInt32($header,4); if($length -lt 0 -or $length -gt 1048576){throw 'Érvénytelen Discord IPC-válasz.'}
    $body=New-Object byte[] $length;$offset=0
    while($offset -lt $length){$read=$pipe.Read($body,$offset,$length-$offset);if($read -le 0){throw 'A Discord IPC-kapcsolat megszakadt.'};$offset+=$read}
    if($length -eq 0){return $null};return ([Text.Encoding]::UTF8.GetString($body)|ConvertFrom-Json)
}

function Disconnect-SoundLiftDiscordPresence {
    if($script:discordPresencePipe){try{$script:discordPresencePipe.Dispose()}catch{};$script:discordPresencePipe=$null}
    $script:lastDiscordPresenceSignature=''
}

function Connect-SoundLiftDiscordPresence {
    if($script:discordPresencePipe -and $script:discordPresencePipe.IsConnected){return $true}
    Disconnect-SoundLiftDiscordPresence
    if(-not (Get-Process Discord -ErrorAction SilentlyContinue)){return $false}
    foreach($index in 0..9){
        try {
            $pipe=[IO.Pipes.NamedPipeClientStream]::new('.',"discord-ipc-$index",[IO.Pipes.PipeDirection]::InOut,[IO.Pipes.PipeOptions]::None)
            $pipe.Connect(80);$pipe.ReadTimeout=1000;$pipe.WriteTimeout=1000
            Write-DiscordPresenceFrame $pipe 0 @{v=1;client_id=$script:discordApplicationId}
            $reply=Read-DiscordPresenceFrame $pipe
            if($reply.evt -eq 'READY'){$script:discordPresencePipe=$pipe;return $true}
            $pipe.Dispose()
        } catch { if($pipe){try{$pipe.Dispose()}catch{}} }
    }
    return $false
}

function Get-SoundLiftSpotifyTrack {
    $titles=@(Get-Process Spotify -ErrorAction SilentlyContinue|Where-Object{-not [string]::IsNullOrWhiteSpace($_.MainWindowTitle)}|Select-Object -ExpandProperty MainWindowTitle -Unique)
    $title=[string]($titles|Where-Object{$_ -notmatch '^(Spotify|Spotify Premium|Advertisement)$'}|Select-Object -First 1)
    if([string]::IsNullOrWhiteSpace($title)){return $null}
    $title=[Regex]::Replace($title,'\s+[-–—]\s+Spotify$','').Trim()
    if($title.Length-gt 120){$title=$title.Substring(0,120)}
    return $title
}

function Set-SoundLiftDiscordPresence([string]$track, [switch]$Clear) {
    if(-not (Connect-SoundLiftDiscordPresence)){return $false}
    $activity=$null
    if(-not $Clear){
        $profile=Get-SoundLiftProfileDisplayName $script:activeProfile
        $details=if([string]::IsNullOrWhiteSpace($track)){'SoundLift aktív'}else{$track}
        $state=if([string]::IsNullOrWhiteSpace($track)){"Aktív profil: $profile"}else{"SoundLift • $profile profil"}
        $started=[DateTimeOffset]$script:sessionStartedUtc
        $activity=@{details=$details;state=$state;timestamps=@{start=$started.ToUnixTimeSeconds()}}
    }
    try {
        Write-DiscordPresenceFrame $script:discordPresencePipe 1 @{cmd='SET_ACTIVITY';args=@{pid=[Diagnostics.Process]::GetCurrentProcess().Id;activity=$activity};nonce=[Guid]::NewGuid().ToString()}
        $reply=Read-DiscordPresenceFrame $script:discordPresencePipe
        if($reply.evt -eq 'ERROR'){throw [string]$reply.data.message}
        return $true
    } catch { Disconnect-SoundLiftDiscordPresence;return $false }
}

$presenceTimer=New-Object Windows.Threading.DispatcherTimer
$presenceTimer.Interval=[TimeSpan]::FromSeconds(8)
$presenceTimer.Add_Tick({
    if(-not $DiscordPresenceCheck.IsChecked){
        if($script:lastDiscordPresenceSignature){[void](Set-SoundLiftDiscordPresence '' -Clear);Disconnect-SoundLiftDiscordPresence}
        return
    }
    if(-not (Get-Process Discord -ErrorAction SilentlyContinue)){Disconnect-SoundLiftDiscordPresence;return}
    $track=Get-SoundLiftSpotifyTrack
    $signature=if($track){"$track|$script:activeProfile"}else{"running|$script:activeProfile"}
    if($signature -eq $script:lastDiscordPresenceSignature -and $script:discordPresencePipe -and $script:discordPresencePipe.IsConnected){return}
    if(Set-SoundLiftDiscordPresence $track){$script:lastDiscordPresenceSignature=$signature}
})
$DiscordPresenceCheck.Add_Click({
    if($DiscordPresenceCheck.IsChecked){$StatusText.Text='A Discord-állapot megjelenítése bekapcsolva';$presenceTimer.Stop();$presenceTimer.Start()}
    else{[void](Set-SoundLiftDiscordPresence '' -Clear);Disconnect-SoundLiftDiscordPresence;$StatusText.Text='A Discord-állapot megjelenítése kikapcsolva'}
    try{(Get-AppState)|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $settingsPath -Encoding UTF8}catch{}
})
# A Discord Rich Presence funkció el lett távolítva; az időzítő nem indul el.

# Optional automatic switching: FiveM has priority, followed by Spotify and Discord.
$script:lastAutoProfile = ''
$autoTimer = New-Object Windows.Threading.DispatcherTimer
$autoTimer.Interval = [TimeSpan]::FromSeconds(4)
$autoTimer.Add_Tick({
    if (-not $AutoProfileCheck.IsChecked) { return }
    $processNames = @(Get-Process -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName)
    $wanted = if ($processNames -match 'FiveM|FiveM_GTAProcess|GTAProcess') { 'FiveM' } elseif ($processNames -contains 'Spotify') { 'Music' } elseif ($processNames -contains 'Discord') { 'Discord' } else { '' }
    if ($wanted -and $wanted -ne $script:lastAutoProfile) {
        $script:lastAutoProfile = $wanted
        if ($wanted -eq 'FiveM') { $GameButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))) }
        elseif ($wanted -eq 'Music') { $MusicButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))) }
        elseif ($wanted -eq 'Discord') { $DiscordButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))) }
        Invoke-ApplyButton
        $automaticName = if ($wanted -eq 'Music') { 'Zene' } elseif ($wanted -eq 'FiveM') { 'FiveM RP' } else { $wanted }
        $StatusText.Text = "Automatikus profilváltás • $automaticName profil aktív"
        if ($script:trayIcon -and -not $script:doNotDisturb) { $script:trayIcon.ShowBalloonTip(1800, 'Profilváltás', "$wanted profil bekapcsolva", [Windows.Forms.ToolTipIcon]::Info) }
    }
})
# Az automatikus profilváltás el lett távolítva; az időzítő nem indul el.

# A SoundLift rendszergazdai joggal fut, ezért a Windows a sima Indítópultból
# nem indítja el megbízhatóan. Bejelentkezéskor egy emelt jogosultságú,
# felhasználóhoz kötött ütemezett feladat indítja el.
$startupTaskName = 'SoundLift – automatikus indítás'
$legacyStartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'SoundLift.lnk'
function Test-SoundLiftStartupTask {
    try { return $null -ne (Get-ScheduledTask -TaskName $startupTaskName -ErrorAction Stop) } catch { return $false }
}
function Enable-SoundLiftStartupTask {
    $userId = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = if ($script:isPackagedExe) {
        New-ScheduledTaskAction -Execute $script:appLaunchPath -WorkingDirectory $script:appDirectory
    } else {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory $script:appDirectory
    }
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $startupTaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'A SoundLift automatikus indítása Windows-bejelentkezéskor.' -Force | Out-Null
    if (Test-Path -LiteralPath $legacyStartupShortcut) { Remove-Item -LiteralPath $legacyStartupShortcut -Force -ErrorAction SilentlyContinue }
}
function Disable-SoundLiftStartupTask {
    Unregister-ScheduledTask -TaskName $startupTaskName -Confirm:$false -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $legacyStartupShortcut) { Remove-Item -LiteralPath $legacyStartupShortcut -Force -ErrorAction SilentlyContinue }
}
$StartupCheck.IsChecked = Test-SoundLiftStartupTask
$StartupCheck.Add_Click({
    try {
        if ($StartupCheck.IsChecked) {
            Enable-SoundLiftStartupTask
            $StatusText.Text = 'A SoundLift automatikusan elindul a következő Windows-bejelentkezéskor'
        } else {
            Disable-SoundLiftStartupTask
            $StatusText.Text = 'A Windowszal történő automatikus indítás kikapcsolva'
        }
    } catch {
        $StartupCheck.IsChecked = Test-SoundLiftStartupTask
        Write-SoundLiftLog -Category crash -EventName 'handled_runtime_error' -Severity error -Data @{ component='startup_task' } -ErrorRecord $_
        Show-SoundLiftMessage "Az automatikus indítás beállítása nem sikerült:`n$($_.Exception.Message)" 'SoundLift – Automatikus indítás' 'OK' 'Error' $window | Out-Null
    }
})
$DoNotDisturbCheck.Add_Click({
    $script:doNotDisturb = [bool]$DoNotDisturbCheck.IsChecked
    $StatusText.Text = if ($script:doNotDisturb) { 'Ne zavarjanak mód bekapcsolva' } else { 'Ne zavarjanak mód kikapcsolva' }
})
$AppVolumeButton.Add_Click({
    try {
        Start-Process 'ms-settings:apps-volume'
        $StatusText.Text='Az alkalmazásonkénti hangerőkeverő megnyitva'
    } catch {
        Show-SoundLiftMessage 'A Windows alkalmazáshangerő-keverője nem nyitható meg ezen a rendszeren.' 'SoundLift' 'OK' 'Warning' $window | Out-Null
    }
})

function Show-MicrophoneEnhancementWindow {
    $dialog=[Windows.Window]::new();$dialog.Title='SoundLift – Mikrofonjavítás';$dialog.Width=580;$dialog.Height=520;$dialog.ResizeMode='NoResize';$dialog.WindowStartupLocation='CenterOwner';$dialog.Owner=$window;Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.StackPanel]::new();$root.Margin=[Windows.Thickness]::new(25)
    $title=[Windows.Controls.TextBlock]::new();$title.Text='Mikrofonjavítás';$title.FontSize=24;$title.FontWeight='Bold';$title.Foreground=$window.Resources['AccentTextBrush'];[void]$root.Children.Add($title)
    $device=[Windows.Controls.TextBlock]::new();$device.Text="Aktív mikrofon: $([AudioAppNative]::GetDefaultInputName())";$device.TextWrapping='Wrap';$device.Foreground='#94A3B8';$device.Margin=[Windows.Thickness]::new(0,5,0,20);[void]$root.Children.Add($device)
    $levelLabel=[Windows.Controls.TextBlock]::new();$levelLabel.Text='Mikrofon hangereje';$levelLabel.FontWeight='SemiBold';[void]$root.Children.Add($levelLabel)
    $level=[Windows.Controls.Slider]::new();$level.Minimum=0;$level.Maximum=100;$level.TickFrequency=5;$level.IsSnapToTickEnabled=$true;$level.Value=[AudioAppNative]::GetDefaultInputVolumePercent();$level.Margin=[Windows.Thickness]::new(0,6,0,4);[void]$root.Children.Add($level)
    $levelValue=[Windows.Controls.TextBlock]::new();$levelValue.Text="$([int]$level.Value)%";$levelValue.Foreground=$window.Resources['AccentTextBrush'];$levelValue.FontWeight='Bold';$levelValue.Margin=[Windows.Thickness]::new(0,0,0,16);[void]$root.Children.Add($levelValue);$level.Add_ValueChanged({$levelValue.Text="$([int]$level.Value)%"}.GetNewClosure())
    $note=[Windows.Controls.TextBlock]::new();$note.Text='A SoundLift közvetlenül a Windows alapértelmezett mikrofonjának bemeneti hangerejét állítja.';$note.TextWrapping='Wrap';$note.Foreground='#94A3B8';$note.Margin=[Windows.Thickness]::new(0,0,0,16);[void]$root.Children.Add($note)
    $tools=[Windows.Controls.StackPanel]::new();$tools.Orientation='Horizontal';$tools.HorizontalAlignment='Left'
    $properties=[Windows.Controls.Button]::new();$properties.Content='Windows mikrofonbeállítások';$properties.Style=$window.Resources['UtilityButton'];$properties.Width=220;$properties.Add_Click({try{Start-Process 'ms-settings:sound'}catch{}}.GetNewClosure())
    [void]$tools.Children.Add($properties);[void]$root.Children.Add($tools)
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.HorizontalAlignment='Right';$actions.Margin=[Windows.Thickness]::new(0,22,0,0)
    $cancel=[Windows.Controls.Button]::new();$cancel.Content='Mégse';$cancel.Style=$window.Resources['UtilityButton'];$cancel.Width=100;$cancel.Add_Click({$dialog.Close()}.GetNewClosure())
    $apply=[Windows.Controls.Button]::new();$apply.Content='Alkalmazás';$apply.Style=$window.Resources['PrimaryButton'];$apply.Width=130;$apply.Add_Click({
        if(-not [AudioAppNative]::SetDefaultInputVolumePercent([single]$level.Value)){Show-SoundLiftMessage 'A mikrofon hangerejét nem sikerült beállítani.' 'SoundLift' 'OK' 'Warning' $dialog|Out-Null;return}
        @{volume=[int]$level.Value;device=[AudioAppNative]::GetDefaultInputName()}|ConvertTo-Json|Set-Content -LiteralPath $microphoneSettingsPath -Encoding UTF8
        $StatusText.Text="Mikrofon hangerő alkalmazva • $([int]$level.Value)%";$dialog.Close()
    }.GetNewClosure());[void]$actions.Children.Add($cancel);[void]$actions.Children.Add($apply);[void]$root.Children.Add($actions);$dialog.Content=$root;$dialog.ShowDialog()|Out-Null
}
$MicrophoneButton.Add_Click({Show-MicrophoneEnhancementWindow})

$NightModeCheck.Add_Click({
    if($NightModeCheck.IsChecked){
        $script:nightModeSnapshot=[PSCustomObject]@{profile=$script:activeProfile;volume=[int]$VolumeSlider.Value;bass=[int]$BassSlider.Value;frequency=[int]$FrequencySlider.Value;safety=[bool]$SafetyCheck.IsChecked;eq=@($script:eqSliders|ForEach-Object{[int]$_.Value})}
        $script:nightModeEnabled=$true;$script:activeProfile='Éjszakai';Set-Profile 110 1 75 $true;Set-EqValues @(-1,0,1,2,2,1,0,-1,-2,-3);$StatusText.Text='Éjszakai mód bekapcsolva • kiegyensúlyozott halk hangzás'
    } else {
        $script:nightModeEnabled=$false
        if($script:nightModeSnapshot){$snapshot=$script:nightModeSnapshot;$script:activeProfile=[string]$snapshot.profile;Set-Profile $snapshot.volume $snapshot.bass $snapshot.frequency $snapshot.safety;Set-EqValues ([double[]]$snapshot.eq)}
        $StatusText.Text='Éjszakai mód kikapcsolva'
    }
    if($InstantCheck.IsChecked){Invoke-ApplyButton}
})
$OverlayCheck.Add_Click({$script:profileOverlayEnabled=[bool]$OverlayCheck.IsChecked;$StatusText.Text=if($script:profileOverlayEnabled){'A profilváltási jelzés bekapcsolva'}else{'A profilváltási jelzés kikapcsolva'}})

# Remember the complete UI state between launches.
if (Test-Path $settingsPath) {
    try { Set-AppState (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json) } catch { }
} else { Apply-ProfileLayout }
if (Test-Path $onboardingMarkerPath) { $script:onboardingCompleted = $true }
$window.Add_Closing({
    try { (Get-AppState) | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsPath -Encoding UTF8 } catch { }
    Save-SoundLiftStatistics
})

# Display the current Windows default output and refresh it automatically.
function Update-DeviceText { $DeviceText.Text = "Aktív hangkimenet: $([AudioAppNative]::GetDefaultOutputName())" }
$deviceTimer = New-Object Windows.Threading.DispatcherTimer
$deviceTimer.Interval = [TimeSpan]::FromSeconds(5)
$deviceTimer.Add_Tick({ Update-DeviceText })
$deviceTimer.Start(); Update-DeviceText

# Live Windows Core Audio peak meter. Values are read locally from the current
# default output and are never stored or sent to the backend.
$script:lastLeftPeak = 0.0
$script:lastRightPeak = 0.0
function Update-LiveAudioMeter {
    try {
        $peaks = [AudioAppNative]::GetDefaultOutputPeaks()
        $left = [Math]::Min(100.0, [Math]::Max([double]$peaks[0] * 100.0, $script:lastLeftPeak * 0.72))
        $right = [Math]::Min(100.0, [Math]::Max([double]$peaks[1] * 100.0, $script:lastRightPeak * 0.72))
        $script:lastLeftPeak = $left; $script:lastRightPeak = $right
        $LeftPeakMeter.Value = $left; $RightPeakMeter.Value = $right
        $LeftPeakText.Text = "$([Math]::Round($left))%"; $RightPeakText.Text = "$([Math]::Round($right))%"
        $volumeBoost = if ([double]$VolumeSlider.Value -le 0) { -100.0 } else { 20.0 * [Math]::Log10([double]$VolumeSlider.Value / 100.0) }
        $LiveBoostText.Text = if ($volumeBoost -le -90) { 'Erősítés: némítva' } else { 'Erősítés: {0:+0.0;-0.0;0.0} dB' -f $volumeBoost }
        $peak = [Math]::Max($left, $right)
        if ($peak -ge 98.5) {
            $LiveClipText.Text = 'TORZÍTÁS'; $LiveClipText.Foreground = '#FB7185'
            $LeftPeakMeter.Foreground = '#FB7185'; $RightPeakMeter.Foreground = '#FB7185'
            if($script:statistics -and ([DateTime]::UtcNow-$script:lastClipStatisticUtc).TotalSeconds -ge 10){$script:statistics.clippingWarnings=[int64]$script:statistics.clippingWarnings+1;$script:lastClipStatisticUtc=[DateTime]::UtcNow}
        } elseif ($peak -ge 85) {
            $LiveClipText.Text = 'MAGAS JELSZINT'; $LiveClipText.Foreground = '#FBBF24'
            $LeftPeakMeter.Foreground = '#FBBF24'; $RightPeakMeter.Foreground = '#FBBF24'
        } elseif ($peak -gt 0.5) {
            $LiveClipText.Text = 'AKTÍV'; $LiveClipText.Foreground = '#4ADE80'
            $LeftPeakMeter.Foreground = $window.Resources['AccentTextBrush']; $RightPeakMeter.Foreground = $window.Resources['AccentTextBrush']
        } else {
            $LiveClipText.Text = 'NINCS JEL'; $LiveClipText.Foreground = '#64748B'
            $LeftPeakMeter.Foreground = $window.Resources['AccentTextBrush']; $RightPeakMeter.Foreground = $window.Resources['AccentTextBrush']
        }
    } catch { }
}
$audioMeterTimer = New-Object Windows.Threading.DispatcherTimer
$audioMeterTimer.Interval = [TimeSpan]::FromMilliseconds(100)
$audioMeterTimer.Add_Tick({ Update-LiveAudioMeter })
$audioMeterTimer.Start()

# Global hotkeys. These also work while a game is focused.
$script:hotKeyButtons = @($MusicButton, $GameButton, $CombatButton, $R6Button, $DiscordButton, $MovieButton)

function Invoke-QuickMute {
    if (-not $script:isQuickMuted) {
        $script:preMuteVolume = [Math]::Max(1, [int]$VolumeSlider.Value)
        $VolumeSlider.Value = 0; $script:isQuickMuted = $true
        $StatusText.Text = 'Gyors némítás bekapcsolva'
    } else {
        $VolumeSlider.Value = $script:preMuteVolume; $script:isQuickMuted = $false
        $StatusText.Text = "Hang visszakapcsolva • $($script:preMuteVolume)%"
    }
    Invoke-ApplyButton
}

function Register-SoundLiftHotKeys {
    if (-not $script:windowHandle) { return }
    for ($i = 0; $i -lt 7; $i++) { [void][AudioAppNative]::UnregisterHotKey($script:windowHandle, 101 + $i) }
    for ($i = 0; $i -lt 7; $i++) {
        $binding = $script:hotKeyBindings[$i]
        if ([int]$binding.key -eq 0) { continue }
        $nativeModifiers = [uint32]([int]$binding.modifiers -bor 0x4000)
        if (-not [AudioAppNative]::RegisterHotKey($script:windowHandle, 101 + $i, $nativeModifiers, [uint32]$binding.key)) {
            throw "A(z) $(Get-SoundLiftHotKeyText $binding) kombinációt egy másik program már használja."
        }
    }
}

function Get-SoundLiftHotKeyText($binding) {
    if (-not $binding -or [int]$binding.key -eq 0) { return 'Nincs beállítva' }
    $parts = [Collections.Generic.List[string]]::new(); $modifiers=[int]$binding.modifiers
    if ($modifiers -band 2) { $parts.Add('Ctrl') }
    if ($modifiers -band 1) { $parts.Add('Alt') }
    if ($modifiers -band 4) { $parts.Add('Shift') }
    if ($modifiers -band 8) { $parts.Add('Win') }
    $key = [Windows.Input.KeyInterop]::KeyFromVirtualKey([int]$binding.key); $keyName=[string]$key
    if($keyName -match '^D([0-9])$'){$keyText=$Matches[1]}
    elseif($keyName -match '^NumPad([0-9])$'){$keyText="Num $($Matches[1])"}
    else{$keyText = switch ($keyName) {
        'Return' {'Enter'} 'Escape' {'Esc'} 'Back' {'Backspace'} 'Next' {'PageDown'} 'Prior' {'PageUp'}
        'OemPlus' {'+'} 'OemMinus' {'-'} 'OemComma' {','} 'OemPeriod' {'.'} 'Space' {'Szóköz'}
        default { $keyName }
    }}
    $parts.Add($keyText); return ($parts -join ' + ')
}

function Test-SoundLiftHotKeyBinding($binding) {
    $key=[int]$binding.key; $modifiers=[int]$binding.modifiers
    if ($key -eq 0) { return $null }
    if ($key -in @(0x10,0x11,0x12,0x5B,0x5C)) { return 'Önmagában módosítóbillentyű nem használható.' }
    if (($modifiers -band 1) -and $key -eq 0x73) { return 'Az Alt + F4 rendszerparancs nem állítható be.' }
    if (($modifiers -band 8) -and $key -in @(0x44,0x4C)) { return 'Ez a Windows rendszerparancs nem állítható be.' }
    if (($modifiers -band 3) -eq 3 -and $key -eq 0x2E) { return 'A Ctrl + Alt + Delete rendszerparancs nem állítható be.' }
    return $null
}

function Show-HotkeyEditor {
    $dialog=[Windows.Window]::new(); $dialog.Title='SoundLift – Billentyűparancsok'; $dialog.Width=620; $dialog.Height=590
    $dialog.ResizeMode='NoResize'; $dialog.WindowStartupLocation='CenterOwner'; $dialog.Owner=$window; Set-SoundLiftWindowStyle $dialog
    $root=[Windows.Controls.Grid]::new(); $root.Margin=[Windows.Thickness]::new(26)
    $root.RowDefinitions.Add([Windows.Controls.RowDefinition]::new()); $actionsRow=[Windows.Controls.RowDefinition]::new(); $actionsRow.Height=[Windows.GridLength]::Auto; $root.RowDefinitions.Add($actionsRow)
    $panel=[Windows.Controls.StackPanel]::new(); $title=[Windows.Controls.TextBlock]::new(); $title.Text='Billentyűparancsok'; $title.FontSize=23; $title.FontWeight='Bold'; $title.Foreground=$window.Resources['AccentTextBrush']; $title.Margin=[Windows.Thickness]::new(0,0,0,5)
    $hint=[Windows.Controls.TextBlock]::new(); $hint.Text='Kattints egy mezőre, majd nyomj le bármilyen betűt, számot, funkcióbillentyűt vagy kombinációt. Az × gomb kikapcsolja az adott parancsot.'; $hint.TextWrapping='Wrap'; $hint.Foreground='#94A3B8'; $hint.Margin=[Windows.Thickness]::new(0,0,0,15)
    [void]$panel.Children.Add($title); [void]$panel.Children.Add($hint)
    $labels=@('Zene','FiveM RP','FiveM PvP','Rainbow Six Siege','Discord','Film','Gyors némítás'); $selectors=@()
    for($i=0;$i -lt $labels.Count;$i++) {
        $row=[Windows.Controls.DockPanel]::new(); $row.Margin=[Windows.Thickness]::new(0,0,0,8)
        $label=[Windows.Controls.TextBlock]::new(); $label.Text=$labels[$i]; $label.Width=250; $label.VerticalAlignment='Center'; $label.FontWeight='SemiBold'
        $right=[Windows.Controls.StackPanel]::new();$right.Orientation='Horizontal';$right.HorizontalAlignment='Right'
        $capture=[Windows.Controls.TextBox]::new(); $capture.Width=198; $capture.Height=34; $capture.IsReadOnly=$true; $capture.Cursor='Hand'; $capture.VerticalContentAlignment='Center'; $capture.Padding=[Windows.Thickness]::new(10,0,10,0)
        $clear=[Windows.Controls.Button]::new();$clear.Content='×';$clear.Width=34;$clear.Height=34;$clear.Margin=[Windows.Thickness]::new(8,0,0,0);$clear.ToolTip='Billentyűparancs kikapcsolása';$clear.Style=$window.Resources['UtilityButton'];$clear.Tag=$capture
        $capture.Tag=[PSCustomObject]@{ modifiers=[int]$script:hotKeyBindings[$i].modifiers; key=[int]$script:hotKeyBindings[$i].key }; $capture.Text=Get-SoundLiftHotKeyText $capture.Tag
        $capture.Add_GotKeyboardFocus({ param($sender,$eventArgs) $sender.Text='Nyomd le a kombinációt…'; $sender.SelectAll() })
        $capture.Add_PreviewKeyDown({
            param($sender,$eventArgs)
            $eventArgs.Handled=$true; $pressedKey=if($eventArgs.Key -eq [Windows.Input.Key]::System){$eventArgs.SystemKey}else{$eventArgs.Key}
            if($pressedKey -in @([Windows.Input.Key]::LeftCtrl,[Windows.Input.Key]::RightCtrl,[Windows.Input.Key]::LeftAlt,[Windows.Input.Key]::RightAlt,[Windows.Input.Key]::LeftShift,[Windows.Input.Key]::RightShift,[Windows.Input.Key]::LWin,[Windows.Input.Key]::RWin)){return}
            $mods=0; $active=[Windows.Input.Keyboard]::Modifiers
            if($active -band [Windows.Input.ModifierKeys]::Control){$mods=$mods-bor 2};if($active -band [Windows.Input.ModifierKeys]::Alt){$mods=$mods-bor 1};if($active -band [Windows.Input.ModifierKeys]::Shift){$mods=$mods-bor 4};if($active -band [Windows.Input.ModifierKeys]::Windows){$mods=$mods-bor 8}
            $candidate=[PSCustomObject]@{modifiers=$mods;key=[Windows.Input.KeyInterop]::VirtualKeyFromKey($pressedKey)}; $problem=Test-SoundLiftHotKeyBinding $candidate
            if($problem){Show-SoundLiftMessage $problem 'Nem használható billentyűparancs' 'OK' 'Warning' $dialog|Out-Null;$sender.Text=Get-SoundLiftHotKeyText $sender.Tag;return}
            $sender.Tag=$candidate;$sender.Text=Get-SoundLiftHotKeyText $candidate
        })
        $clear.Add_Click({param($sender,$eventArgs)$target=$sender.Tag;$target.Tag=[PSCustomObject]@{modifiers=0;key=0};$target.Text='Nincs beállítva'})
        [void]$right.Children.Add($capture);[void]$right.Children.Add($clear);[Windows.Controls.DockPanel]::SetDock($right,'Right'); [void]$row.Children.Add($right); [void]$row.Children.Add($label); [void]$panel.Children.Add($row); $selectors += $capture
    }
    $buttons=[Windows.Controls.StackPanel]::new(); $buttons.Orientation='Horizontal'; $buttons.HorizontalAlignment='Right'; $buttons.Margin=[Windows.Thickness]::new(0,14,0,0)
    $cancel=[Windows.Controls.Button]::new(); $cancel.Content='Mégse'; $cancel.Width=100; $cancel.Margin=[Windows.Thickness]::new(0,0,10,0); $cancel.Style=$window.Resources['UtilityButton']
    $save=[Windows.Controls.Button]::new(); $save.Content='Mentés'; $save.Width=120; $save.Style=$window.Resources['PrimaryButton']
    $cancel.Add_Click({$dialog.Close()}.GetNewClosure())
    $save.Add_Click({
        $bindings=@($selectors|ForEach-Object{$_.Tag});$activeSignatures=@($bindings|Where-Object{[int]$_.key -ne 0}|ForEach-Object{"$($_.modifiers):$($_.key)"})
        if ((@($activeSignatures|Select-Object -Unique)).Count -ne $activeSignatures.Count) { Show-SoundLiftMessage 'Ugyanaz a kombináció csak egy parancshoz használható.' 'Billentyűütközés' 'OK' 'Warning' $dialog|Out-Null; return }
        $singleKeys=@($bindings|Where-Object{[int]$_.key -ne 0 -and [int]$_.modifiers -eq 0})
        if($singleKeys.Count -gt 0){
            $answer=Show-SoundLiftMessage 'Önálló billentyűt is beállítottál. Ez gépelés és játék közben is aktiválhatja a hozzárendelt profilt. Biztosan mented?' 'Önálló gyorsbillentyű' 'YesNo' 'Warning' $dialog
            if($answer -ne 'Yes'){return}
        }
        $previous=@($script:hotKeyBindings); $script:hotKeyBindings=@($bindings|ForEach-Object{[PSCustomObject]@{modifiers=[int]$_.modifiers;key=[int]$_.key}});$script:hotKeyVirtualKeys=@($script:hotKeyBindings|ForEach-Object{[int]$_.key})
        try { Register-SoundLiftHotKeys; $dialog.Close(); $StatusText.Text='A billentyűparancsok mentve'; (Get-AppState)|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $settingsPath -Encoding UTF8 } catch { $script:hotKeyBindings=$previous; $script:hotKeyVirtualKeys=@($previous|ForEach-Object{[int]$_.key}); Register-SoundLiftHotKeys; Show-SoundLiftMessage $_.Exception.Message 'Billentyűütközés' 'OK' 'Warning' $dialog|Out-Null }
    }.GetNewClosure())
    [void]$buttons.Children.Add($cancel); [void]$buttons.Children.Add($save); [Windows.Controls.Grid]::SetRow($buttons,1); [void]$root.Children.Add($panel); [void]$root.Children.Add($buttons); $dialog.Content=$root; $dialog.ShowDialog()|Out-Null
}
$HotkeyButton.Add_Click({ Show-HotkeyEditor })

$script:hotKeyHook = [Windows.Interop.HwndSourceHook]{
    param([IntPtr]$hookHwnd, [int]$message, [IntPtr]$wParam, [IntPtr]$lParam, [ref]$handled)
    if ($message -eq 0x0312) {
        $index = $wParam.ToInt32() - 101
        if ($index -ge 0 -and $index -lt $script:hotKeyButtons.Count) {
            $script:hotKeyButtons[$index].RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
            Invoke-ApplyButton; $handled.Value = $true
        } elseif ($wParam.ToInt32() -eq 107) {
            Invoke-QuickMute; $handled.Value = $true
        }
    }
    return [IntPtr]::Zero
}
$window.Add_SourceInitialized({
    $helper = New-Object Windows.Interop.WindowInteropHelper($window)
    $script:windowHandle = $helper.Handle
    # Use Windows' native dark title bar while keeping the normal resize,
    # minimize, maximize and close controls. Attribute 20 is used by current
    # Windows builds; 19 is the compatibility fallback for older Windows 10.
    try {
        $darkTitleBar = 1
        $result = [AudioAppNative]::DwmSetWindowAttribute($script:windowHandle, 20, [ref]$darkTitleBar, 4)
        if ($result -ne 0) { [void][AudioAppNative]::DwmSetWindowAttribute($script:windowHandle, 19, [ref]$darkTitleBar, 4) }
    } catch { }
    $script:windowSource = [Windows.Interop.HwndSource]::FromHwnd($script:windowHandle)
    $script:windowSource.AddHook($script:hotKeyHook)
    try { Register-SoundLiftHotKeys } catch { $StatusText.Text=$_.Exception.Message; $StatusBorder.Background='#4A1F2D' }
})

# Tray quick menu. The NotifyIcon itself was intentionally created much
# earlier, directly after the window and icon resources were initialized.
$trayMenu = New-Object Windows.Forms.ContextMenuStrip
$showItem = $trayMenu.Items.Add('Megnyitás')
function Show-SoundLiftMainWindow {
    $window.Show()
    $window.WindowState = [Windows.WindowState]::Normal
    $window.ShowInTaskbar = $true
    [void]$window.Activate()
    $window.Topmost = $true; $window.Topmost = $false
    [void]$window.Focus()
}
$showItem.Add_Click({ Show-SoundLiftMainWindow })
[void]$trayMenu.Items.Add('-')
$searchLabel = New-Object Windows.Forms.ToolStripLabel -ArgumentList 'Profil keresése:'; $searchLabel.ForeColor=[Drawing.Color]::Gray; [void]$trayMenu.Items.Add($searchLabel)
$searchBox = New-Object Windows.Forms.ToolStripTextBox
$searchBox.ToolTipText = 'Írj be egy profilnevet'; [void]$trayMenu.Items.Add($searchBox)
$profileMenu = New-Object Windows.Forms.ToolStripMenuItem -ArgumentList 'Gyorsprofilok'
$trayProfiles = @(
    @('Zene', $MusicButton), @('FiveM RP', $GameButton), @('FiveM PvP', $CombatButton),
    @('Rainbow Six Siege', $R6Button), @('Discord', $DiscordButton), @('Film', $MovieButton)
)
$script:trayProfileItems = @()
foreach ($entry in $trayProfiles) {
    $profileButton = $entry[1]
    $item = $profileMenu.DropDownItems.Add([string]$entry[0])
    $item.CheckOnClick = $false
    $item.Tag = [string]$entry[0]
    $item.Add_Click({ $profileButton.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent))); Invoke-ApplyButton }.GetNewClosure())
    $script:trayProfileItems += $item
}
[void]$trayMenu.Items.Add($profileMenu)
$searchBox.Add_TextChanged({
    $query=$searchBox.Text.Trim()
    foreach($profileItem in $script:trayProfileItems){$profileItem.Visible=[string]::IsNullOrWhiteSpace($query) -or $profileItem.Text.IndexOf($query,[StringComparison]::OrdinalIgnoreCase)-ge 0}
    $profileMenu.ShowDropDown()
}.GetNewClosure())
$volumeMenu = New-Object Windows.Forms.ToolStripMenuItem -ArgumentList 'Hangerő'
$volumeDownItem = $volumeMenu.DropDownItems.Add('− 5%')
$volumeDownItem.Add_Click({ $VolumeSlider.Value=[Math]::Max(0,[int]$VolumeSlider.Value-5); Invoke-ApplyButton })
$volumeUpItem = $volumeMenu.DropDownItems.Add('+ 5%')
$volumeUpItem.Add_Click({ $VolumeSlider.Value=[Math]::Min(300,[int]$VolumeSlider.Value+5); Invoke-ApplyButton })
[void]$volumeMenu.DropDownItems.Add('-')
$script:trayVolumeItems = @()
foreach ($volumeLevel in @(0,50,100,125,150,175,200,250,300)) {
    $targetVolume = [int]$volumeLevel
    $volumeItem = New-Object Windows.Forms.ToolStripMenuItem -ArgumentList "$targetVolume%"
    $volumeItem.Tag = $targetVolume
    $volumeItem.Add_Click({ $VolumeSlider.Value=$targetVolume; $script:isQuickMuted=($targetVolume -eq 0); Invoke-ApplyButton }.GetNewClosure())
    [void]$volumeMenu.DropDownItems.Add($volumeItem); $script:trayVolumeItems += $volumeItem
}
[void]$trayMenu.Items.Add($volumeMenu)
$muteItem = $trayMenu.Items.Add('Gyors némítás')
$muteItem.Add_Click({ Invoke-QuickMute })
$bypassItem = $trayMenu.Items.Add('SoundLift-hatások kikapcsolása')
$bypassItem.Add_Click({ if($script:isBypassed){Disable-SoundLiftBypass}else{Invoke-SoundLiftBypass $false} })
$windowsSoundItem = $trayMenu.Items.Add('Windows hangbeállítások')
$windowsSoundItem.Add_Click({ try { Start-Process 'ms-settings:sound' } catch { } })
$dndItem = New-Object Windows.Forms.ToolStripMenuItem -ArgumentList 'Ne zavarjanak mód'; $dndItem.CheckOnClick=$true; $dndItem.Checked=$script:doNotDisturb
$dndItem.Add_CheckedChanged({$script:doNotDisturb=$dndItem.Checked; $DoNotDisturbCheck.IsChecked=$script:doNotDisturb}.GetNewClosure()); [void]$trayMenu.Items.Add($dndItem)
$trayMenu.Add_Opening({
    $volumeMenu.Text="Hangerő • $([int]$VolumeSlider.Value)%"
    foreach($volumeItem in $script:trayVolumeItems){$volumeItem.Checked=([int]$volumeItem.Tag -eq [int]$VolumeSlider.Value)}
    $muteItem.Text=if($script:isQuickMuted){'Hang visszakapcsolása'}else{'Gyors némítás'}
    $bypassItem.Text=if($script:isBypassed){'SoundLift-hatások visszakapcsolása'}else{'SoundLift-hatások kikapcsolása'}
    $bypassItem.Checked=$script:isBypassed
    $profileNames=@{'Music'='Zene';'FiveM RP'='FiveM RP';'FiveM Combat'='FiveM PvP';'R6'='Rainbow Six Siege';'Discord'='Discord';'Movie'='Film'}
    $activeTrayName=$profileNames[[string]$script:activeProfile]
    foreach($profileItem in $script:trayProfileItems){$profileItem.Checked=($profileItem.Text -eq $activeTrayName)}
})
[void]$trayMenu.Items.Add('-')
$exitItem = $trayMenu.Items.Add('Kilépés')
$exitItem.Add_Click({
    $script:reallyExit = $true
    $script:trayIcon.Visible = $false
    $script:trayIcon.Dispose()
    $window.Close()
})
$script:trayIcon.ContextMenuStrip = $trayMenu
$script:trayIcon.Add_DoubleClick({ Show-SoundLiftMainWindow })
# Re-register after the complete context menu is attached. This also makes the
# icon appear reliably when Explorer was still starting during app launch.
$script:trayIcon.Visible = $false
$script:trayIcon.Visible = $true
# A minimalizálás normál Windows-módon működik: az app látható marad a tálcán.
# Csak az X gomb rejti a tálcaikon mellé, ahonnan dupla kattintással visszahozható.
$window.Add_StateChanged({
    if ($window.WindowState -eq 'Minimized') {
        $window.ShowInTaskbar = $true
    }
})
$window.Add_Closing({
    param($sender, $eventArgs)
    if (-not $script:reallyExit) {
        $eventArgs.Cancel = $true
        $window.Hide()
        $script:trayIcon.Visible = $true
        if (-not $script:trayHintShown -and -not $script:doNotDisturb) {
            $script:trayHintShown = $true
            $script:trayIcon.ShowBalloonTip(2200, 'A SoundLift tovább fut', 'Dupla kattintással bármikor visszanyithatod.', [Windows.Forms.ToolTipIcon]::Info)
        }
    }
})
$window.Add_Closed({
    $presenceTimer.Stop()
    $audioMeterTimer.Stop()
    Save-SoundLiftStatistics
    if($script:discordPresencePipe){[void](Set-SoundLiftDiscordPresence '' -Clear);Disconnect-SoundLiftDiscordPresence}
    for ($i = 0; $i -lt 7; $i++) { [void][AudioAppNative]::UnregisterHotKey($script:windowHandle, 101 + $i) }
    if ($script:windowSource) { $script:windowSource.RemoveHook($script:hotKeyHook) }
})

Update-Labels
$script:startupUiHandled = $false
$window.Add_ContentRendered({
    if ($script:startupUiHandled) { return }
    $script:startupUiHandled = $true
    try {
        if (-not (Confirm-SoundLiftLicense)) {
            Write-SoundLiftLog -Category startup -EventName 'initialization_failed' -Severity warning -Data @{ stage='license_gate' }
            [void](Send-SoundLiftPendingLogs)
            $script:reallyExit = $true; $window.Close(); return
        }
        Update-DeveloperControls
        Show-PostUpdateResult
        if (-not $script:onboardingCompleted) { Show-FirstRunWizard } else { Test-AndOfferSoundLiftRepair }
        Complete-SoundLiftStartup
        Start-AsyncAppUpdateCheck
    } catch {
        Write-SoundLiftLog -Category startup -EventName 'initialization_failed' -Severity critical -ErrorRecord $_
        Write-SoundLiftLog -Category crash -EventName 'startup_crash' -Severity critical -ErrorRecord $_
        [void](Send-SoundLiftPendingLogs)
        Show-SoundLiftMessage "A SoundLift indítása közben hiba történt.`nA részletes napló itt található:`n$script:logRoot" 'SoundLift – indítási hiba' 'OK' 'Error' $window | Out-Null
        $script:reallyExit = $true; $window.Close()
    }
})
try {
    $window.ShowDialog() | Out-Null
} catch {
    $eventName = if ($script:startupCompleted) { 'unhandled_runtime_error' } else { 'startup_crash' }
    Write-SoundLiftLog -Category crash -EventName $eventName -Severity critical -ErrorRecord $_
    if (-not $script:startupCompleted) { Write-SoundLiftLog -Category startup -EventName 'initialization_failed' -Severity critical -ErrorRecord $_ }
    [void](Send-SoundLiftPendingLogs)
    Show-SoundLiftMessage "A SoundLift váratlan hibával leállt.`nA jelentés helyileg el lett mentve:`n$script:logRoot" 'SoundLift – hiba' 'OK' 'Error' $window | Out-Null
}
