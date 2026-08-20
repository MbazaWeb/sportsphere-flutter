// SportSphere — Safaricom Daraja STK Push (Lipa Na M-Pesa Online)
// Secrets: MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_SHORTCODE, MPESA_PASSKEY, MPESA_ENV (sandbox|production)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = await req.json();
    const orderId = body.order_id as string;
    const phone = normalizePhone(String(body.phone ?? ""));
    const amount = Math.max(1, Math.round(Number(body.amount ?? 0)));

    if (!orderId || !phone || amount < 1) {
      return new Response(JSON.stringify({ error: "order_id, phone, amount required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const env = Deno.env.get("MPESA_ENV") ?? "sandbox";
    const key = Deno.env.get("MPESA_CONSUMER_KEY") ?? "";
    const secret = Deno.env.get("MPESA_CONSUMER_SECRET") ?? "";
    const shortcode = Deno.env.get("MPESA_SHORTCODE") ?? "174379";
    const passkey = Deno.env.get("MPESA_PASSKEY") ?? "";
    const callback =
      Deno.env.get("MPESA_CALLBACK_URL") ??
      `${Deno.env.get("SUPABASE_URL")}/functions/v1/mpesa-callback`;

    if (!key || !secret || !passkey) {
      return new Response(
        JSON.stringify({
          error: "M-Pesa secrets not configured",
          hint: "Set MPESA_CONSUMER_KEY, MPESA_CONSUMER_SECRET, MPESA_PASSKEY",
        }),
        { status: 503, headers: { ...cors, "Content-Type": "application/json" } },
      );
    }

    const token = await getAccessToken(env, key, secret);
    const ts = timestamp();
    const password = btoa(`${shortcode}${passkey}${ts}`);

    const stkRes = await fetch(
      `${mpesaBase(env)}/mpesa/stkpush/v1/processrequest`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
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

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    await supabase.from("ShopOrder").update({
      status: stkJson.ResponseCode === "0" ? "stk_sent" : "stk_failed",
      paymentMethod: "mpesa",
      paymentRef: stkJson.CheckoutRequestID ?? null,
    }).eq("id", orderId);

    return new Response(JSON.stringify(stkJson), {
      status: stkRes.ok ? 200 : 400,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
