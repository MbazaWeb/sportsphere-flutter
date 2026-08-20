import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const body = await req.json();
    const result = body?.Body?.stkCallback;
    const checkoutId = result?.CheckoutRequestID as string | undefined;
    const code = result?.ResultCode;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    if (checkoutId) {
      await supabase.from("ShopOrder").update({
        status: code === 0 ? "paid" : "failed",
        paymentRef: checkoutId,
      }).eq("paymentRef", checkoutId);
    }
    return new Response(JSON.stringify({ ResultCode: 0, ResultDesc: "Accepted" }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 200 });
  }
});
