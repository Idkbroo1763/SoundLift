$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..'
$client=[IO.File]::ReadAllText((Join-Path $root 'SoundLift.ps1'))
$verify=[IO.File]::ReadAllText((Join-Path $root 'licensing\verify-license\index.ts'))
$schema=[IO.File]::ReadAllText((Join-Path $root 'licensing\supabase-schema.sql'))
$admin=[IO.File]::ReadAllText((Join-Path $root 'licensing\admin-license-action\index.ts'))
foreach($marker in @('extra_bass_pro','voice_boost','custom_preset_x','soundlift_license_features','get_soundlift_license_features','is_owner')){
 if(-not $schema.Contains($marker)){throw "Missing schema entitlement marker: $marker"}
}
foreach($marker in @('p_discord_id: linkedUser.discord_user_id','DISCORD_ACCOUNT_MISMATCH','list_owner_targets','simulation_license_id','OWNER_REQUIRED','get_soundlift_license_features','license_validation_summary','stableEventId','device_changed','device_change_rejected','license_variant','server_check:"online"','request_device_change','soundlift_device_change_requests','device_change_requested')){
 if(-not $verify.Contains($marker)){throw "Missing secure entitlement backend marker: $marker"}
}
foreach($marker in @('set_license_feature','upsert_feature','set_owner','set_status','license_status_changed','feature_permission')){if(-not $admin.Contains($marker)){throw "Missing admin action: $marker"}}
foreach($marker in @("activation_kind <> 'validated'",'license_status','customer_name','transfer_count')){if(-not $schema.Contains($marker)){throw "Missing usage-efficient license audit marker: $marker"}}
foreach($marker in @('Set-LicenseFeatures','Show-OwnerLicenseSimulator','OwnerModeButton','ExtraBassProButton','VoiceBoostButton','CustomPresetXButton')){
 if(-not $client.Contains($marker)){throw "Missing client entitlement feature: $marker"}
}
foreach($marker in @('$activate.IsDefault=$true','$dialog.DialogResult=$true','LICENSE_DIALOG_INVALID_KEY')){
 if(-not $client.Contains($marker)){throw "Missing reliable license dialog behavior: $marker"}
}
if(-not $client.Contains("[Regex]::Match(`$candidate,'(?i)SL-[A-F0-9]{32}')")){throw 'License key extraction is missing'}
if($client.Contains('$candidate=[string]$input.Text')){throw 'License dialog still uses the reserved PowerShell input variable'}
if(-not $client.Contains('$candidate=[string]$licenseInput.Text')){throw 'License dialog is not reading its textbox'}
if($client.Contains("`$script:isOwner = `$true")){throw 'Owner permission is hard-coded in the client'}
foreach($marker in @('app_version=$script:appVersion','build_channel=$buildChannel','offline_grace_used','server_check=''offline''')){if(-not $client.Contains($marker)){throw "Missing detailed client license logging marker: $marker"}}
foreach($marker in @('function Show-LicenseManagerWindow','$LicenseButton.Add_Click','Invoke-LicenseApi ([string]$saved.key) ''request_device_change''','currentLicenseStatus','currentLicenseActivatedUtc','request_device_change')){if(-not $client.Contains($marker)){throw "Missing V1.6.0 license manager marker: $marker"}}
foreach($marker in @('soundlift_device_change_requests','soundlift_device_change_one_pending_idx','activated_at','device_ref')){if(-not $schema.Contains($marker)){throw "Missing device-change schema marker: $marker"}}
if($client.Contains("-EventName `$eventName -Data @{ license_type=`$response.license_type")){throw 'Duplicate successful client-side license logging is still present'}
Write-Host 'PASS: backend-gated flags, Discord ownership, Owner simulation and client visibility wiring'
