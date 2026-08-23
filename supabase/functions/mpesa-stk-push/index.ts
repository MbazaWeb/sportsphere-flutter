// SportSphere — Safaricom Daraja STK Push (Lipa Na M-Pesa Online)
// Secrets: MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_SHORTCODE,
//          MPESA_PASSKEY, MPESA_ENV (sandbox|production)
//
// Security (H10 + M18):
//   - Caller MUST present a valid JWT in the Authorization header.
//   - The client-provided `amount` is IGNORED entirely. The amount is read
//     from the ShopOrder row in Supabase (verified to belong to the caller).
//   - CORS Origin is whitelisted via the ALLOWED_ORIGINS env var.
//
// POST body: { order_id: string, phone: string }
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

function mpesaBase(env: string) {
  return env === "production"
    ? "https://api.safaricom.co.ke"
    : "https://sandbox.safaricom.co.ke";
}

async function getAccessToken(env: string, key: string, secret: string) {
  const auth = btoa(`${key}:${secret}`);
  const res = await fetch(`${mpesaBase(env)}/oauth/v1/generate?grant_type=client_credentials`, {
    headers: { Authorization: `Basic ${auth}` },
  });
  if (!res.ok) throw new Error(`M-Pesa token failed: ${await res.text()}`);
  const json = await res.json();
  return json.access_token as string;
}

function timestamp() {
  const d = new Date();
  const p = (n: number) => n.toString().padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

function normalizePhone(phone: string): string {
  let p = phone.replace(/\D/g, "");
  if (p.startsWith("0")) p = "254" + p.slice(1);
  if (p.startsWith("+")) p = p.slice(1);
  if (!p.startsWith("254")) p = "254" + p;
  return p;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(req) });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  try {
    // ── Auth check (added) ──
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
      console.error("mpesa-stk-push: invalid token", userErr?.message);
      return json({ error: "Invalid or expired token" }, 401, req);
    }
    const callerUid = userData.user.id;

    // ── Parse body: ONLY order_id + phone. Client amount is IGNORED (H10). ──
    const body = await req.json();
    const orderId = body.order_id as string;
    const phone = normalizePhone(String(body.phone ?? ""));

    if (!orderId || !phone) {
      return json({ error: "order_id and phone required" }, 400, req);
    }

    // ── H10: Look up the order; use DB amountTzs (never trust client). ────────
    const { data: order, error: orderErr } = await supabase
      .from("ShopOrder")
      .select('id, "userId", "amountTzs", status')
      .eq("id", orderId)
      .maybeSingle();

    if (orderErr) {
      console.error("mpesa-stk-push: ShopOrder lookup error", orderErr.message);
      return json({ error: "Order lookup failed" }, 500, req);
    }
    if (!order) {
      return json({ error: "Order not found" }, 400, req);
    }
    if (order.userId !== callerUid) {
      console.error(
        `mpesa-stk-push: order ${orderId} belongs to ${order.userId}, not caller ${callerUid}`,
      );
      return json({ error: "Order does not belong to caller" }, 403, req);
    }

    const amount = Math.max(1, Math.round(Number(order.amountTzs ?? 0)));
    if (amount < 1) {
      return json({ error: "Order amount is invalid" }, 400, req);
    }

    // ── M-Pesa env config ─────────────────────────────────────────────────────
    const env = Deno.env.get("MPESA_ENV") ?? "sandbox";
    const key = Deno.env.get("MPESA_CONSUMER_KEY") ?? "";
    const secret = Deno.env.get("MPESA_CONSUMER_SECRET") ?? "";
    const shortcode = Deno.env.get("MPESA_SHORTCODE") ?? "174379";
    const passkey = Deno.env.get("MPESA_PASSKEY") ?? "";
    const callback =
      Deno.env.get("MPESA_CALLBACK_URL") ??
      `${supabaseUrl}/functions/v1/mpesa-callback`;

    if (!key || !secret || !passkey) {
      return json(
        {
          error: "M-Pesa secrets not configured",
          hint: "Set MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_PASSKEY",
        },
        503,
        req,
      );
    }

    const mpesaToken = await getAccessToken(env, key, secret);
    const ts = timestamp();
    const password = btoa(`${shortcode}${passkey}${ts}`);

    const stkRes = await fetch(
      `${mpesaBase(env)}/mpesa/stkpush/v1/processrequest`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${mpesaToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          BusinessShortCode: shortcode,
          Password: password,
          Timestamp: ts,
          TransactionType: "CustomerPayBillOnline",
          Amount: amount,
          PartyA: phone,
          PartyB: shortcode,
          PhoneNumber: phone,
          CallBackURL: callback,
          AccountReference: orderId.slice(0, 12),
          TransactionDesc: "SportSphere",
        }),
      },
    );
    const stkJson = await stkRes.json();

    // ── Persist CheckoutRequestID on the order so the callback can match it ──
    const adminClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    await adminClient.from("ShopOrder").update({
      status: stkJson.ResponseCode === "0" ? "stk_sent" : "stk_failed",
      paymentMethod: "mpesa",
      paymentRef: stkJson.CheckoutRequestID ?? null,
    }).eq("id", orderId);

    return json(stkJson, stkRes.ok ? 200 : 400, req);
  } catch (e) {
    console.error("mpesa-stk-push error:", String(e));
    return json({ error: String(e) }, 500, req);
  }
});
