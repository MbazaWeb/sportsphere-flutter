// Edge Function: ai-assistant
// POST { mode, prompt, provider }
//
// Security (C3 + M18):
//   - Caller MUST present a valid JWT in the Authorization header.
//   - Rate-limited to 20 calls / hour / user (in-memory counter; resets on cold start).
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

// ─── In-memory rate limiter (20 calls / hour / user) ──────────────────────────
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
const RATE_LIMIT_MAX = 20;
const rateBuckets = new Map<string, { count: number; resetAt: number }>();

function rateLimitCheck(userId: string): { ok: boolean; remaining: number; resetAt: number } {
  const now = Date.now();
  const bucket = rateBuckets.get(userId);
  if (!bucket || bucket.resetAt < now) {
    const resetAt = now + RATE_LIMIT_WINDOW_MS;
    rateBuckets.set(userId, { count: 1, resetAt });
    return { ok: true, remaining: RATE_LIMIT_MAX - 1, resetAt };
  }
  if (bucket.count >= RATE_LIMIT_MAX) {
    return { ok: false, remaining: 0, resetAt: bucket.resetAt };
  }
  bucket.count += 1;
  return { ok: true, remaining: RATE_LIMIT_MAX - bucket.count, resetAt: bucket.resetAt };
}

// Opportunistic cleanup — drop expired buckets every ~5 minutes.
let lastCleanup = Date.now();
function rateLimitCleanup() {
  const now = Date.now();
  if (now - lastCleanup < 5 * 60 * 1000) return;
  lastCleanup = now;
  for (const [uid, b] of rateBuckets) {
    if (b.resetAt < now) rateBuckets.delete(uid);
  }
}

// ─── Handler ──────────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  try {
    // ── Auth check (C3) ──
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
      console.error("ai-assistant: invalid token", userErr?.message);
      return json({ error: "Invalid or expired token" }, 401, req);
    }
    const callerUid = userData.user.id;

    // ── Rate limit (max 20 / hour / user) ──
    rateLimitCleanup();
    const rl = rateLimitCheck(callerUid);
    if (!rl.ok) {
      return json(
        { error: "Rate limit exceeded", retryAfterSeconds: Math.ceil((rl.resetAt - Date.now()) / 1000) },
        429,
        req,
      );
    }

    // ── Parse body ──
    const { mode, prompt, provider } = await req.json();
    if (!prompt || typeof prompt !== "string") {
      return json({ error: "prompt required" }, 400, req);
    }

    const system = {
      news: "You are Playify news desk. Write concise Tanzania sports news in English.",
      article: "You are a sports journalist. Write a structured article with headline and short paragraphs.",
      moderate: "You moderate a sports social app. Flag toxicity, spam, or false claims. Reply with verdict and reason.",
      chat: "You are Playify assistant. Help fans, players and admins with the app.",
      caption: "Write a short social post caption with 2-4 hashtags for Playify.",
    }[mode as string] || "You are Playify assistant.";

    const useAnthropic = provider === "anthropic";
    if (useAnthropic) {
      const key = Deno.env.get("ANTHROPIC_API_KEY");
      if (!key) throw new Error("ANTHROPIC_API_KEY not set");
      const res = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": key,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-3-5-haiku-20241022",
          max_tokens: 1024,
          system,
          messages: [{ role: "user", content: prompt }],
        }),
      });
      const data = await res.json();
      const text = data?.content?.[0]?.text ?? JSON.stringify(data);
      return json({ text, provider: "anthropic", remaining: rl.remaining }, 200, req);
    }

    const key = Deno.env.get("DEEPSEEK_API_KEY");
    if (!key) throw new Error("DEEPSEEK_API_KEY not set");
    const res = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [
          { role: "system", content: system },
          { role: "user", content: prompt },
        ],
      }),
    });
    const data = await res.json();
    const text = data?.choices?.[0]?.message?.content ?? JSON.stringify(data);
    return json({ text, provider: "deepseek", remaining: rl.remaining }, 200, req);
  } catch (e) {
    console.error("ai-assistant error:", String(e));
    return json({ error: String(e) }, 500, req);
  }
});
