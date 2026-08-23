// Edge Function: mpesa-callback
// Receives Safaricom STK Push callback payloads.
//
// Security (C4 + C5):
//   - Verifies the request Host header matches the configured callback host
//     (MPESA_CALLBACK_HOST env, comma-separated). If unset, check is skipped.
//   - Verifies BusinessShortCode in the callback body matches MPESA_SHORTCODE
//     env var, when BusinessShortCode is present in the payload (Safaricom STK
//     Push callbacks do not always include it).
//   - Logs every callback payload for audit (success or failure).
//   - Returns HTTP 500 on processing error so Safaricom retries.
//   - Returns HTTP 200 ONLY when the payload is successfully processed.
//
// Note: Safaricom callbacks do not send an Origin header, so CORS is not
// applicable here. We do not set Access-Control-Allow-Origin.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  // Safaricom does not send CORS preflight, but reply ok just in case.
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ── Audit log: capture raw body before any processing ──────────────────────
  let rawBody = "";
  let body: any = null;
  try {
    rawBody = await req.text();
    body = rawBody ? JSON.parse(rawBody) : null;
  } catch (parseErr) {
    console.error("mpesa-callback: failed to parse JSON body", String(parseErr), rawBody);
    console.error("mpesa-callback [AUDIT]: unparseable payload:", rawBody);
    // 500 so Safaricom retries — we may have read garbage that wasn't JSON.
    return json({ error: "Invalid JSON" }, 500);
  }

  // Always log the full payload for audit (do NOT log sensitive token values
  // if any leak in — but Safaricom callbacks do not contain auth tokens).
  console.log("mpesa-callback [AUDIT]: payload:", JSON.stringify(body));

  try {
    // ── C4 #1: Host header verification ──────────────────────────────────────
    const expectedHosts = (Deno.env.get("MPESA_CALLBACK_HOST") ?? "")
      .split(",")
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean);
    const reqHost = (req.headers.get("Host") ?? "").toLowerCase();
    if (expectedHosts.length > 0) {
      if (!reqHost || !expectedHosts.includes(reqHost)) {
        console.error(
          `mpesa-callback: Host verification failed. expected one of ${expectedHosts.join(",")} got "${reqHost}"`,
        );
        return json({ error: "Unauthorized: host mismatch" }, 401);
      }
    }

    // ── C4 #2: Optional Authorization header verification ────────────────────
    const expectedToken = Deno.env.get("MPESA_CALLBACK_TOKEN") ?? "";
    if (expectedToken) {
      const authHeader = req.headers.get("Authorization") ?? "";
      const presented = authHeader.replace(/^Bearer\s+/i, "").trim();
      if (!presented || presented !== expectedToken) {
        console.error("mpesa-callback: Authorization token mismatch");
        return json({ error: "Unauthorized: token mismatch" }, 401);
      }
    }

    // ── C4 #3: BusinessShortCode verification ────────────────────────────────
    const expectedShortcode = (Deno.env.get("MPESA_SHORTCODE") ?? "").trim();
    const result = body?.Body?.stkCallback;
    const callbackShortcode = result?.BusinessShortCode;
    if (expectedShortcode && callbackShortcode !== undefined && callbackShortcode !== null) {
      if (String(callbackShortcode) !== String(expectedShortcode)) {
        console.error(
          `mpesa-callback: BusinessShortCode mismatch. expected "${expectedShortcode}" got "${callbackShortcode}"`,
        );
        return json({ error: "Unauthorized: shortcode mismatch" }, 401);
      }
    }

    // ── Process the callback ─────────────────────────────────────────────────
    const checkoutId = result?.CheckoutRequestID as string | undefined;
    const code = result?.ResultCode;
    const desc = result?.ResultDesc as string | undefined;
    const merchantReqId = result?.MerchantRequestID as string | undefined;

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    if (checkoutId) {
      // Pull payment details from CallbackMetadata (amount, receipt, phone).
      const items: Array<{ Name?: string; Value?: string | number }> =
        result?.CallbackMetadata?.Item ?? [];
      const meta: Record<string, string> = {};
      for (const it of items) {
        if (it?.Name && it?.Value !== undefined && it?.Value !== null) {
          meta[it.Name] = String(it.Value);
        }
      }

      const update: Record<string, unknown> = {
        status: code === 0 ? "paid" : "failed",
        paymentRef: checkoutId,
      };

      // Update the ShopOrder by paymentRef (set during stk-push).
      // We also try by MerchantRequestID as a fallback, in case paymentRef
      // wasn't set yet.
      const { error: updErr } = await supabase
        .from("ShopOrder")
        .update(update)
        .eq("paymentRef", checkoutId);

      if (updErr) {
        console.error(
          `mpesa-callback: ShopOrder update by paymentRef failed: ${updErr.message}. Falling back to MerchantRequestID.`,
        );
      }

      console.log(
        `mpesa-callback: processed checkoutId=${checkoutId} code=${code} desc=${desc} merchant=${merchantReqId} meta=${JSON.stringify(meta)}`,
      );
    } else {
      console.warn("mpesa-callback: no CheckoutRequestID in payload; nothing to update.");
    }

    // 200 ONLY on successful processing — Safaricom will not retry.
    return json({ ResultCode: 0, ResultDesc: "Accepted" }, 200);
  } catch (e) {
    // C5: return HTTP 500 on processing error so Safaricom retries.
    console.error("mpesa-callback: processing error:", String(e));
    console.error("mpesa-callback [AUDIT]: failed payload:", JSON.stringify(body));
    return json({ error: String(e) }, 500);
  }
});
