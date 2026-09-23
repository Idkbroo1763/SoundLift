import { authenticateInstallation } from "../_shared/installation-auth.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { storeAndForwardEvent } from "../_shared/backend-logger.ts";

const headers = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers });
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

async function stableEventId(value: string) {
  const hex = await sha256(value);
  return `${hex.slice(0,8)}-${hex.slice(8,12)}-5${hex.slice(13,16)}-a${hex.slice(17,20)}-${hex.slice(20,32)}`;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return reply(405, { allowed: false, message: "Method not allowed." });
  const contentLength = Number.parseInt(request.headers.get("content-length") ?? "0", 10);
  if (Number.isFinite(contentLength) && contentLength > 4096) return reply(413, { allowed: false, message: "Request too large." });

  try {
    const body = await request.json();
    const licenseKey = String(body.license_key ?? "").trim();
    const productId = String(body.product_id ?? "").trim();
    const deviceId = String(body.device_id ?? "").trim().toLowerCase();
    const installationId = String(body.installation_id ?? "").trim().toLowerCase();
    const action = String(body.action ?? "verify");
    const simulationLicenseId = String(body.simulation_license_id ?? "").trim().toLowerCase();
    const appVersion = String(body.app_version ?? "unknown").trim().slice(0,24);
    const buildChannel = String(body.build_channel ?? "public").trim().toLowerCase().slice(0,24);
    if (!["verify","list_owner_targets","request_device_change"].includes(action) || licenseKey.length < 24 || licenseKey.length > 160 || !/^[a-f0-9]{64}$/.test(deviceId) || !/^[a-z0-9][a-z0-9_-]{2,63}$/.test(productId) || !uuidPattern.test(installationId)) {
      return reply(400, { allowed: false, code: "INVALID_REQUEST", message: "Érvénytelen licenckérés." });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    if (!await authenticateInstallation(supabase, installationId, String(body.installation_proof ?? ""))) return reply(403, {allowed:false, code:"INVALID_INSTALLATION_PROOF"});
    const { data: linkedUser, error: linkError } = await supabase.from("soundlift_installation_links").select("discord_user_id,discord_username,discord_global_name").eq("installation_id", installationId).is("revoked_at", null).maybeSingle();
    if (linkError) throw linkError;
    if (!linkedUser) {
      await storeAndForwardEvent(supabase, { category: "security", event_name: "license_without_discord_link", severity: "warning", installation_id: installationId, product_id: productId, source: "backend", trusted: true, metadata: { support_id: `SL-${installationId.replaceAll("-", "").slice(0, 8).toUpperCase()}` } });
      return reply(403, { allowed: false, code: "DISCORD_LINK_REQUIRED", message: "A licenc használatához előbb kapcsold össze a Discord-fiókodat." });
    }
    const keyHash = await sha256(licenseKey);
    const { data, error } = await supabase.rpc("activate_soundlift_license", {
      p_key_hash: keyHash,
      p_product_code: productId,
      p_device_id: deviceId,
      p_discord_id: linkedUser.discord_user_id,
    });
    if (error) throw error;
    const allowed = data?.allowed === true;
    const rejectedCode = String(data?.code ?? "UNKNOWN");
    const isSecurity = !allowed && ["INVALID_LICENSE", "LICENSE_BLOCKED", "LICENSE_EXPIRED", "DEVICE_LIMIT", "DISCORD_ACCOUNT_MISMATCH"].includes(rejectedCode);
    if (!allowed) {
      const rejectedEvent = rejectedCode === "DEVICE_LIMIT" ? "device_change_rejected" : rejectedCode === "LICENSE_BLOCKED" ? "license_revoked_or_suspended" : "license_rejected";
      await storeAndForwardEvent(supabase, {
        category: isSecurity ? "security" : "license", event_name: rejectedEvent, severity: "warning",
        app_version: appVersion, product_id: productId, installation_id: installationId, source: "backend", trusted: true,
        metadata: {
          support_id: `SL-${installationId.replaceAll("-", "").slice(0, 8).toUpperCase()}`,
          discord_user: `<@${linkedUser.discord_user_id}>`, discord_name: String(linkedUser.discord_global_name || linkedUser.discord_username || "ismeretlen").slice(0,80),
          code: rejectedCode, license_type: data?.license_type ?? "unknown",
          license_variant: data?.license_type === "developer" ? "fejlesztői" : data?.license_type ? "normál/egyedi" : "ismeretlen",
          license_status: data?.license_status ?? (rejectedCode === "LICENSE_BLOCKED" ? "revoked_or_suspended" : "unknown"),
          license_ref: data?.internal_license_id ?? `unknown-${keyHash.slice(0,12)}`, device_ref: deviceId.slice(0,12),
          customer_build: String(data?.customer_name ?? "általános").slice(0,80), build_channel: buildChannel,
          server_check: "online", machine_binding: rejectedCode === "DEVICE_LIMIT" ? "other_device" : "unchanged",
        },
      });
      const publicData = { ...data };
      delete publicData.internal_license_id;
      delete publicData.activation_event;
      return reply(403, publicData);
    }

    const actualLicenseId = String(data.internal_license_id);
    const isOwner = data.is_owner === true;
    if (action === "request_device_change") {
      const { data: existing, error: existingError } = await supabase.from("soundlift_device_change_requests").select("id,requested_at").eq("license_id",actualLicenseId).eq("status","pending").maybeSingle();
      if (existingError) throw existingError;
      if (!existing) {
        const { error: requestError } = await supabase.from("soundlift_device_change_requests").insert({license_id:actualLicenseId,installation_id:installationId,current_device_ref:deviceId.slice(0,12)});
        if (requestError) throw requestError;
        await storeAndForwardEvent(supabase,{category:"license",event_name:"device_change_requested",severity:"warning",app_version:appVersion,product_id:productId,installation_id:installationId,source:"backend",trusted:true,metadata:{support_id:`SL-${installationId.replaceAll("-","").slice(0,8).toUpperCase()}`,discord_user:`<@${linkedUser.discord_user_id}>`,license_ref:actualLicenseId,license_type:data.license_type,device_ref:deviceId.slice(0,12),request_status:"pending"}});
      }
      return reply(200,{allowed:true,code:existing ? "DEVICE_CHANGE_ALREADY_PENDING" : "DEVICE_CHANGE_REQUESTED",message:existing ? "Már van függőben lévő gépcsere-kérelmed." : "A gépcsere-kérelem elküldve.",request_status:"pending"});
    }
    if (action === "list_owner_targets") {
      if (!isOwner) {
        await storeAndForwardEvent(supabase, { category:"security",event_name:"owner_mode_rejected",severity:"warning",installation_id:installationId,source:"backend",trusted:true,metadata:{ license_ref:actualLicenseId } });
        return reply(403, { allowed:false,code:"OWNER_REQUIRED",message:"Ehhez tulajdonosi jogosultság szükséges." });
      }
      const { data: targets, error: targetError } = await supabase
        .from("licenses")
        .select("id,customer_name,license_type,status,expires_at,license_products!inner(product_id)")
        .eq("license_products.product_id", productId)
        .eq("status", "active")
        .order("customer_name", { ascending:true });
      if (targetError) throw targetError;
      const safeTargets = (targets ?? []).filter((item:any) => !item.expires_at || new Date(item.expires_at) > new Date()).map((item:any) => ({
        license_id:item.id,
        label:String(item.customer_name || `Licenc ${String(item.id).slice(0,8)}`).slice(0,80),
        license_type:item.license_type,
      }));
      return reply(200, { allowed:true,is_owner:true,targets:safeTargets });
    }

    let entitlementLicenseId = actualLicenseId;
    let simulatedLicense: Record<string,unknown>|null = null;
    if (simulationLicenseId) {
      if (!isOwner) return reply(403, { allowed:false,code:"OWNER_REQUIRED",message:"Ehhez tulajdonosi jogosultság szükséges." });
      if (!uuidPattern.test(simulationLicenseId)) return reply(400, { allowed:false,code:"INVALID_SIMULATION_TARGET",message:"Érvénytelen tesztlicenc." });
      const { data: target, error: targetError } = await supabase
        .from("licenses")
        .select("id,customer_name,status,expires_at,license_products!inner(product_id)")
        .eq("id",simulationLicenseId).eq("license_products.product_id",productId).maybeSingle();
      if (targetError) throw targetError;
      if (!target || target.status !== "active" || (target.expires_at && new Date(target.expires_at) <= new Date())) {
        return reply(404, { allowed:false,code:"SIMULATION_TARGET_UNAVAILABLE",message:"A kiválasztott tesztlicenc nem használható." });
      }
      entitlementLicenseId = target.id;
      simulatedLicense = { license_id:target.id,label:String(target.customer_name || `Licenc ${target.id.slice(0,8)}`).slice(0,80) };
      await storeAndForwardEvent(supabase, { category:"developer_access",event_name:"owner_license_simulation",severity:"warning",installation_id:installationId,source:"backend",trusted:true,metadata:{ owner_license_ref:actualLicenseId,simulated_license_ref:target.id } });
    }

    const { data: features, error: featureError } = await supabase.rpc("get_soundlift_license_features", { p_license_id:entitlementLicenseId });
    if (featureError) throw featureError;
    const enabledFeatures = (features ?? []).filter((item:any) => item.enabled !== false).map((item:any) => String(item.feature_key)).sort();
    const licenseVariant = data.license_type === "developer" ? "fejlesztői" : enabledFeatures.length ? "egyedi" : "normál";
    const activationEvent = String(data.activation_event ?? "validated");
    const logEventName = data.license_type === "developer" ? "developer_license_authorized" : activationEvent === "device_attached_after_transfer" ? "device_changed" : activationEvent === "activated" ? "device_bound" : "license_validation_summary";
    const eventId = activationEvent === "validated" ? await stableEventId(`${actualLicenseId}|${deviceId}|${new Date().toISOString().slice(0,10)}|${logEventName}`) : undefined;
    await storeAndForwardEvent(supabase, {
      event_id:eventId, category:data.license_type === "developer" ? "developer_access" : "license",
      event_name:logEventName, severity:data.license_type === "developer" ? "warning" : "info",
      app_version:appVersion, product_id:productId, installation_id:installationId, source:"backend", trusted:true,
      metadata:{
        support_id:`SL-${installationId.replaceAll("-","").slice(0,8).toUpperCase()}`,
        discord_user:`<@${linkedUser.discord_user_id}>`, discord_name:String(linkedUser.discord_global_name || linkedUser.discord_username || "ismeretlen").slice(0,80),
        license_ref:entitlementLicenseId, license_type:data.license_type ?? "customer", license_variant:licenseVariant,
        license_status:data.license_status ?? "active", customer_build:String(data.customer_name ?? "általános").slice(0,80),
        app_version:appVersion, build_channel:buildChannel, device_ref:deviceId.slice(0,12),
        machine_binding:activationEvent === "device_attached_after_transfer" ? "changed" : activationEvent === "activated" ? "new_binding" : "unchanged",
        server_check:"online", features_enabled:enabledFeatures.length ? enabledFeatures.join(", ") : "nincs",
      },
    });
    const publicData = { ...data, is_owner:isOwner, features:features ?? [], license_variant:licenseVariant, device_ref:deviceId.slice(0,12), simulated_license:simulatedLicense };
    delete publicData.internal_license_id;
    delete publicData.activation_event;
    return reply(200, publicData);
  } catch (error) {
    try {
      const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
      await storeAndForwardEvent(supabase, { category: "license", event_name: "license_backend_error", severity: "error", source: "backend", trusted: true, metadata: { error_type: error instanceof Error ? error.name : "unknown" } });
    } catch { /* A válasz akkor is titokmentes marad, ha a naplózás sem érhető el. */ }
    return reply(500, { allowed: false, code: "SERVER_ERROR", message: "A licencellenőrzés átmenetileg nem érhető el." });
  }
});
