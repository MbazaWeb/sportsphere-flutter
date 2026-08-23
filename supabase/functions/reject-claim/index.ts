// Edge Function: reject-claim
// POST { claimId: string, reviewNotes?: string }
//
// Security (H9 + M18):
//   - Caller MUST present a valid JWT in the Authorization header.
//   - Caller's role (from profiles / User) MUST be one of:
//     'admin', 'official', 'organization'.
//   - This is a defence-in-depth check BEFORE calling the RPC. The RPC
//     `reject_claim` itself also has an `is_app_admin()` guard.
//   - CORS Origin is whitelisted via the ALLOWED_ORIGINS env var.
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

const ADMIN_ROLES = new Set(["admin", "official", "organization"]);

// ─── Handler ──────────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
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
      console.error("reject-claim: invalid token", userErr?.message);
      return json({ error: "Invalid or expired token" }, 401, req);
    }
    const callerUid = userData.user.id;

    // ── 2. Verify admin role (H9) ──────────────────────────────────────────
    let isAdmin = false;
    try {
      const { data: adminFlag } = await supabase.rpc("is_app_admin");
      isAdmin = Boolean(adminFlag);
    } catch (e) {
      console.error("reject-claim: is_app_admin RPC failed", String(e));
    }

    if (!isAdmin) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", callerUid)
        .maybeSingle();
      const role = String(profile?.role ?? "").toLowerCase();
      if (!ADMIN_ROLES.has(role)) {
        return json({ error: "Forbidden: admin role required" }, 403, req);
      }
    }

    // ── 3. Parse body & call the RPC ───────────────────────────────────────
    const { claimId, reviewNotes } = await req.json();
    if (!claimId) {
      return json({ error: "claimId required" }, 400, req);
    }

    const { data, error } = await supabase.rpc("reject_claim", {
      p_claim_id: claimId,
      p_review_notes: reviewNotes ?? null,
    });

    if (error) {
      console.error("reject-claim: RPC error", error.message);
      return json({ error: error.message }, 400, req);
    }
    return json({ ok: true, data }, 200, req);
  } catch (e) {
    console.error("reject-claim error:", String(e));
    return json({ error: String(e) }, 500, req);
  }
});
