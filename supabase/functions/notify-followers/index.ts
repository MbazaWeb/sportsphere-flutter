// Edge Function: notify-followers
// POST { post_id: string }
//
// Security (M8 + M18):
//   - Caller MUST present a valid JWT in the Authorization header.
//   - Caller MUST be the author of the post identified by `post_id`,
//     OR an app admin (is_app_admin() returns true).
//   - The function:
//       1. Verifies caller is authenticated.
//       2. Accepts a `post_id` parameter.
//       3. Looks up the post's author; verifies caller == author (or admin).
//       4. Queries all followers of the author.
//       5. Inserts a Notification row for each follower (via the
//          `notify_followers` SECURITY DEFINER RPC).
//       6. Sends an FCM push to every follower with a device token.
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

// ─── FCM helpers (inlined to keep the function self-contained) ────────────────
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
    // ── 1. Auth check ──────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) {
      return json({ error: "Missing Authorization header" }, 401, req);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      console.error("notify-followers: invalid token", userErr?.message);
      return json({ error: "Invalid or expired token" }, 401, req);
    }
    const callerUid = userData.user.id;

    // ── 2. Accept post_id ──────────────────────────────────────────────────
    const body = await req.json();
    const postId = body.post_id as string;
    if (!postId || typeof postId !== "string") {
      return json({ error: "post_id required" }, 400, req);
    }

    // ── 3. Look up the post's author (and content) ─────────────────────────
    const { data: post, error: postErr } = await supabase
      .from("Post")
      .select('id, "userId", content')
      .eq("id", postId)
      .maybeSingle();

    if (postErr) {
      console.error("notify-followers: Post lookup error", postErr.message);
      return json({ error: postErr.message }, 500, req);
    }
    if (!post) {
      return json({ error: "Post not found" }, 404, req);
    }

    // ── 3b. Verify caller is the author (or admin) ─────────────────────────
    let isAdmin = false;
    try {
      const { data: adminFlag } = await supabase.rpc("is_app_admin");
      isAdmin = Boolean(adminFlag);
    } catch (e) {
      console.error("notify-followers: is_app_admin check failed", String(e));
    }

    if (post.userId !== callerUid && !isAdmin) {
      return json(
        { error: "Forbidden: only the post author or an admin can notify followers" },
        403,
        req,
      );
    }

    const authorId = post.userId as string;
    const content = String(post.content ?? "").trim();
    const notifTitle = "New post";
    const notifBody = content.length > 80 ? `${content.slice(0, 80)}…` : content;

    // ── 4 + 5. Insert notifications for each follower via the RPC ───────────
    // (The RPC is SECURITY DEFINER; it queries Follow internally and inserts
    //  one Notification row per follower.)
    const { data: notifiedCount, error: rpcErr } = await supabase.rpc("notify_followers", {
      p_author_id: authorId,
      p_title: notifTitle,
      p_body: notifBody || null,
      p_reference_id: postId,
    });

    if (rpcErr) {
      console.error("notify-followers: RPC failed", rpcErr.message);
      // Continue — we still want to attempt FCM delivery.
    }

    // ── 6. Send FCM to followers with device tokens ────────────────────────
    let fcmSent = 0;
    const saRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";
    if (!saRaw) {
      // FCM is optional; not having it configured is not a fatal error.
      console.warn("notify-followers: FIREBASE_SERVICE_ACCOUNT_JSON not set; skipping FCM");
    } else {
      try {
        const saJson = saRaw.trimStart().startsWith("{")
          ? saRaw
          : new TextDecoder().decode(Uint8Array.from(atob(saRaw), (c) => c.charCodeAt(0)));
        const sa = JSON.parse(saJson);

        // Service-role client to read followers + device tokens (bypasses RLS).
        const adminClient = createClient(
          supabaseUrl,
          Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
        );

        // 4. Query followers of the author.
        const { data: followers, error: followerErr } = await adminClient
          .from("Follow")
          .select('"followerId"')
          .eq('"followingId"', authorId);

        if (followerErr) {
          console.error("notify-followers: follower lookup failed", followerErr.message);
        } else if (followers && followers.length > 0) {
          const followerIds = followers.map((f) => f.followerId as string);

          // Read all device tokens for these followers in one query.
          const { data: tokenRows, error: tokenErr } = await adminClient
            .from("device_tokens")
            .select("token")
            .in("user_id", followerIds);

          if (tokenErr) {
            console.error("notify-followers: device_tokens lookup failed", tokenErr.message);
          } else if (tokenRows && tokenRows.length > 0) {
            const accessToken = await getAccessToken(sa);

            for (const row of tokenRows) {
              try {
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
                        token: row.token as string,
                        notification: { title: notifTitle, body: notifBody },
                        data: {
                          post_id: postId,
                          author_id: authorId,
                          type: "new_post",
                        },
                        android: { priority: "high" },
                      },
                    }),
                  },
                );
                if (res.ok) fcmSent++;
                else {
                  const errText = await res.text();
                  console.error(`notify-followers: FCM error for token: ${errText}`);
                }
              } catch (e) {
                console.error("notify-followers: FCM send failed", String(e));
              }
            }
          }
        }
      } catch (e) {
        console.error("notify-followers: FCM block failed", String(e));
      }
    }

    return json(
      { ok: true, notified: notifiedCount ?? 0, fcm_sent: fcmSent },
      200,
      req,
    );
  } catch (e) {
    console.error("notify-followers error:", String(e));
    return json({ error: String(e) }, 500, req);
  }
});
