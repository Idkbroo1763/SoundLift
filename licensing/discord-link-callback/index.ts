import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { storeAndForwardEvent } from "../_shared/backend-logger.ts";

const htmlHeaders = new Headers({
  "Content-Type": "text/html; charset=UTF-8",
  "Cache-Control": "no-store",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'",
});

const page = (ok: boolean, message: string, status = 200) => {
  const accent = ok ? "#4ade80" : "#fb7185";
  const icon = ok ? "✓" : "!";
  const title = ok ? "Sikeres összekapcsolás" : "Az összekapcsolás sikertelen";
  const html = `<!doctype html>
<html lang="hu">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>SoundLift – Discord</title>
  <style>
    *{box-sizing:border-box}body{font-family:"Segoe UI",Arial,sans-serif;background:radial-gradient(circle at top,#260b13 0,#09090b 48%,#050506 100%);color:#f8fafc;display:grid;place-items:center;min-height:100vh;margin:0;padding:24px}.box{width:min(100%,620px);padding:42px;border:1px solid #3f2630;border-radius:22px;background:rgba(18,18,22,.96);box-shadow:0 24px 80px rgba(0,0,0,.55);text-align:center}.brand{color:#ff4d67;font-size:13px;font-weight:800;letter-spacing:.18em;margin-bottom:24px}.icon{display:grid;place-items:center;width:64px;height:64px;margin:0 auto 20px;border:2px solid ${accent};border-radius:50%;color:${accent};font-size:34px;font-weight:800;background:#0c0c10}h1{margin:0 0 14px;color:${accent};font-size:clamp(25px,5vw,36px)}p{margin:10px 0;color:#d4d9e2;font-size:16px;line-height:1.65}.hint{margin-top:25px;padding:14px 18px;border:1px solid #303038;border-radius:12px;background:#0c0c10;color:#aeb7c6}
  </style>
</head>
<body><main class="box"><div class="brand">SOUNDLIFT</div><div class="icon">${icon}</div><h1>${title}</h1><p>${message}</p><p class="hint">Ezt a lapot bezárhatod, majd visszatérhetsz a SoundLift alkalmazásba.</p></main></body>
</html>`;
  // A kódolt bájttömb és a pontos HTML MIME-típus megakadályozza, hogy az
  // Edge Function átjáró forráskódként vagy hibás ékezetekkel jelenítse meg.
  return new Response(new TextEncoder().encode(html), { status, headers: htmlHeaders });
};

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

const supportId = (id: string) => `SL-${id.replaceAll("-", "").slice(0, 8).toUpperCase()}`;

Deno.serve(async (request) => {
  if (request.method !== "GET") return page(false, "Érvénytelen kérés.", 405);
  try {
    const url = new URL(request.url);
    const code = url.searchParams.get("code") ?? "";
    const state = url.searchParams.get("state") ?? "";
    if (code.length < 8 || state.length < 32) return page(false, "Hiányzó vagy érvénytelen Discord-válasz.", 400);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: session, error: sessionError } = await supabase.from("soundlift_link_sessions").select("id,installation_id,expires_at,used_at").eq("state_hash", await sha256(state)).maybeSingle();
    if (sessionError || !session || session.used_at || Date.parse(session.expires_at) < Date.now()) return page(false, "A kapcsolókód lejárt vagy már fel lett használva.", 400);

    const clientId = Deno.env.get("DISCORD_CLIENT_ID") ?? "";
    const clientSecret = Deno.env.get("DISCORD_CLIENT_SECRET") ?? "";
    const redirectUri = Deno.env.get("DISCORD_REDIRECT_URI") ?? "";
    const form = new URLSearchParams({ client_id: clientId, client_secret: clientSecret, grant_type: "authorization_code", code, redirect_uri: redirectUri });
    const tokenResponse = await fetch("https://discord.com/api/oauth2/token", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: form });
    if (!tokenResponse.ok) return page(false, "A Discord nem fogadta el az engedélyezést.", 400);
    const token = await tokenResponse.json();
    const userResponse = await fetch("https://discord.com/api/users/@me", { headers: { authorization: `Bearer ${token.access_token}` } });
    if (!userResponse.ok) return page(false, "A Discord-fiók nem olvasható.", 400);
    const user = await userResponse.json();
    const discordId = String(user.id ?? "");
    if (!/^\d{15,25}$/.test(discordId)) return page(false, "Érvénytelen Discord-fiók.", 400);

    const { data: completed, error: linkError } = await supabase.rpc("complete_soundlift_discord_link", {
      p_session_id: session.id, p_discord_id: discordId,
      p_username: String(user.username ?? ""), p_global_name: String(user.global_name ?? "")
    });
    if (linkError) throw linkError;
    if (!completed) return page(false, "A kapcsolat már fel lett használva vagy másik fiókhoz tartozik.", 409);
    await storeAndForwardEvent(supabase, { category: "security", event_name: "discord_account_linked", severity: "info", installation_id: session.installation_id, source: "backend", trusted: true, metadata: { support_id: supportId(session.installation_id), discord_user: `<@${discordId}>`, discord_name: String(user.global_name || user.username || "ismeretlen").slice(0, 80) } });
    return page(true, "A Discord-fiókod sikeresen hozzá lett kapcsolva ehhez a SoundLift-telepítéshez.");
  } catch {
    return page(false, "Átmeneti szerverhiba történt. Próbáld újra később.", 500);
  }
});
