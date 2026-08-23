// Edge Function: admin-delete-user
// POST { user_id: string }
//
// Purpose (C8 partial):
//   Replaces the client-side `auth.admin.deleteUser()` call (which fails with
//   the anon key) with a server-side call that uses the SUPABASE_SERVICE_ROLE_KEY.
//
// Security:
//   - Caller MUST present a valid JWT in the Authorization header.
//   - Caller MUST be an app admin (is_app_admin() returns true via DB query).
//     Defence-in-depth: also verifies the `role` column directly.
//   - Only AFTER the admin check passes is the SUPABASE_SERVICE_ROLE_KEY used.
//   - The DB trigger `trg_cleanup_user_on_auth_delete` (migration
//     20260825000000_scan_report_fixes.sql) cascade-deletes the matching
//     `public."User"` row when the auth.users row is deleted.
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

const ADMIN_ROLES = new Set(["admin", "official", "organization", "moderator"]);

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
      console.error("admin-delete-user: invalid token", userErr?.message);
      return json({ error: "Invalid or expired token" }, 401, req);
    }
    const callerUid = userData.user.id;

    // ── 2. Verify caller is admin (C8) ─────────────────────────────────────
    let isAdmin = false;
    try {
      const { data: adminFlag } = await supabase.rpc("is_app_admin");
      isAdmin = Boolean(adminFlag);
    } catch (e) {
      console.error("admin-delete-user: is_app_admin RPC failed", String(e));
    }

    if (!isAdmin) {
      // Defence-in-depth: check role column directly.
      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", callerUid)
        .maybeSingle();
      const role = String(profile?.role ?? "").toLowerCase();
      if (!ADMIN_ROLES.has(role)) {
        console.error(
          `admin-delete-user: caller ${callerUid} with role "${role}" is not admin`,
        );
        return json({ error: "Forbidden: admin role required" }, 403, req);
      }
    }

    // ── 3. Parse body ──────────────────────────────────────────────────────
    const { user_id } = await req.json();
    if (!user_id || typeof user_id !== "string") {
      return json({ error: "user_id required" }, 400, req);
    }

    // Prevent self-deletion (an admin should not be able to lock themselves out
    // by deleting their own auth account).
    if (user_id === callerUid) {
      return json({ error: "Cannot delete your own account via this endpoint" }, 400, req);
    }

    // ── 4. Use service-role key to delete the user from auth ───────────────
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { error: deleteErr } = await adminClient.auth.admin.deleteUser(user_id);
    if (deleteErr) {
      console.error("admin-delete-user: auth.admin.deleteUser failed", deleteErr.message);
      return json({ error: deleteErr.message }, 500, req);
    }

    // The trigger `trg_cleanup_user_on_auth_delete` already cascade-deleted
    // the matching public."User" row. As a safety net (in case the trigger
    // is missing in some environments), also try a direct delete here.
    try {
      await adminClient.from("User").delete().eq("id", user_id);
    } catch (e) {
      console.warn("admin-delete-user: User row cleanup fallback failed:", String(e));
    }
    try {
      await adminClient.from("profiles").delete().eq("id", user_id);
    } catch (e) {
      console.warn("admin-delete-user: profiles row cleanup fallback failed:", String(e));
    }

    console.log(`admin-delete-user: caller ${callerUid} deleted user ${user_id}`);
    return json({ ok: true, deleted: user_id }, 200, req);
  } catch (e) {
    console.error("admin-delete-user error:", String(e));
    return json({ error: String(e) }, 500, req);
  }
});
