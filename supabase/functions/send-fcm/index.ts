// Requires FCM_SERVER_KEY (legacy) or use HTTP v1 later
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { user_id, title, body, data } = await req.json();
    const serverKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
    if (!serverKey) {
      return new Response(JSON.stringify({ error: "FCM_SERVER_KEY not set" }), {
        status: 503,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", user_id);
    const results = [];
    for (const row of tokens ?? []) {
      const res = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          Authorization: `key=${serverKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          to: row.token,
          notification: { title, body },
          data: data ?? {},
        }),
      });
      results.push(await res.json());
    }
    return new Response(JSON.stringify({ sent: results.length, results }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
