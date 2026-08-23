// Sends push notifications via FCM HTTP v1 API using a Firebase service account.
// Required secret: FIREBASE_SERVICE_ACCOUNT_JSON (the full service-account key JSON).
//
// Security (C2 + M18):
//   - Caller MUST present a valid JWT in the Authorization header.
//   - Caller may only send FCM to themselves (user_id == caller.id),
//     OR they must be an app admin (is_app_admin() returns true).
//   - CORS Origin is whitelisted via the ALLOWED_ORIGINS env var.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── CORS helpers ─────────────────────────────────────────────────────────────
function getAllowedOrigin(req: Request): string | null {
  const origin = req.headers.get("Origin");
  if (!origin) return null;
  const raw = Deno.env.get("ALLOWED_ORIGINS") ?? "";
  const allowed = raw.split(",").map((s) => s.trim()).filter(Boolean);
  return allowed.includes(origin) ? origin : null;
}

function corsHeaders(req: Request): Record<string, string> {
  const origin = getAllowedOrigin(req);
  const h: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  if (origin) h["Access-Control-Allow-Origin"] = origin;
  return h;
}

function json(body: unknown, status: number, req: Request): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

// ─── FCM helpers ──────────────────────────────────────────────────────────────
function b64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pkcs8Bytes(privateKeyPem: string): Uint8Array {
  const b64 = privateKeyPem
    .replace(/\\n/g, "\n")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr;
}

let cachedToken: { token: string; exp: number } | null = null;

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  if (cachedToken && cachedToken.exp > Date.now() / 1000 + 60) return cachedToken.token;

  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pkcs8Bytes(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${b64url(new Uint8Array(sig))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth failed: ${res.status} ${await res.text()}`);
  const json = await res.json();
  cachedToken = { token: json.access_token, exp: now + (json.expires_in ?? 3600) };
  return json.access_token;
}

// ─── Handler ──────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  try {
    // ── Auth check (C2) ──
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return json({ error: "Missing Authorization header" }, 401, req);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: userData, error: userErr } = await userClient.auth.getUser(token);
    if (userErr || !userData?.user) {
      console.error("send-fcm: invalid token", userErr?.message);
      return json({ error: "Invalid or expired token" }, 401, req);
    }
    const callerUid = userData.user.id;

    // ── Parse body ──
    const { user_id, title, body, data } = await req.json();
    if (!user_id || typeof user_id !== "string") {
      return json({ error: "user_id required" }, 400, req);
    }

    // ── Authorization: caller must own the target user_id, OR be an admin ──
    let isAdmin = false;
    try {
      const { data: adminFlag } = await userClient.rpc("is_app_admin");
      isAdmin = Boolean(adminFlag);
    } catch (e) {
      console.error("send-fcm: is_app_admin check failed", String(e));
    }

    if (user_id !== callerUid && !isAdmin) {
      return json({ error: "Forbidden: can only send FCM to your own devices" }, 403, req);
    }

    // ── Load Firebase service account ──
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
    if (!saRaw) {
      return json({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }, 503, req);
    }
    const saJson = saRaw.trimStart().startsWith("{")
      ? saRaw
      : new TextDecoder().decode(Uint8Array.from(atob(saRaw), (c) => c.charCodeAt(0)));
    const sa = JSON.parse(saJson);

    // ── Service-role client to read device tokens (bypasses RLS) ──
    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: tokens, error } = await adminClient
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id);
    if (error) throw new Error(error.message);

    const accessToken = await getAccessToken(sa);
    const results: unknown[] = [];
    let sent = 0;

    for (const row of tokens ?? []) {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token: row.token,
              notification: { title, body },
              data: Object.fromEntries(
                Object.entries(data ?? {}).map(([k, v]) => [k, String(v)]),
              ),
              android: { priority: "high" },
            },
          }),
        },
      );
      const jsonBody = await res.json();
      if (res.ok) sent++;
      else console.error(`FCM error for token: ${JSON.stringify(jsonBody)}`);
      results.push(jsonBody);
    }

    return json({ sent, results }, 200, req);
  } catch (e) {
    console.error("send-fcm error:", String(e));
    return json({ error: String(e) }, 500, req);
  }
});
