// Sends push notifications via FCM HTTP v1 API using a Firebase service account.
// Required secret: FIREBASE_SERVICE_ACCOUNT_JSON (the full service-account key JSON).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { user_id, title, body, data } = await req.json();

    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
    if (!saRaw) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT_JSON not set" }), {
        status: 503,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    // Accepts raw JSON or base64-encoded JSON.
    const saJson = saRaw.trimStart().startsWith("{")
      ? saRaw
      : new TextDecoder().decode(Uint8Array.from(atob(saRaw), (c) => c.charCodeAt(0)));
    const sa = JSON.parse(saJson);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: tokens, error } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id);
    if (error) throw new Error(error.message);

    const accessToken = await getAccessToken(sa);
    const results = [];
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
      const json = await res.json();
      if (res.ok) sent++;
      else console.error(`FCM error for token: ${JSON.stringify(json)}`);
      results.push(json);
    }

    return new Response(JSON.stringify({ sent, results }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
