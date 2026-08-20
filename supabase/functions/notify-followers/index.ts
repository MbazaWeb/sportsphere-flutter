// Edge Function: notify-followers
// POST { authorId: string, title: string, body?: string, referenceId?: string }
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization" }), { status: 401 });
    }

    const { authorId, title, body, referenceId } = await req.json();
    if (!authorId || !title) {
      return new Response(JSON.stringify({ error: "authorId and title required" }), { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: user } = await supabase.auth.getUser();
    if (!user.user || user.user.id !== authorId) {
      // allow service role callers; anon JWT must match author
      const role = (await supabase.auth.getSession()).data.session?.user?.role;
      if (user.user?.id !== authorId) {
        return new Response(JSON.stringify({ error: "Can only notify as yourself" }), { status: 403 });
      }
    }

    const { data, error } = await supabase.rpc("notify_followers", {
      p_author_id: authorId,
      p_title: title,
      p_body: body ?? null,
      p_reference_id: referenceId ?? null,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }
    return new Response(JSON.stringify({ ok: true, notified: data }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
