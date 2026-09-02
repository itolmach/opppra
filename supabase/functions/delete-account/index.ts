// Supabase Edge Function: delete-account
//
// Deletes the calling user's own auth.users row. Everything else the user
// owns (profile, lists, list_items, attendance_logs, recommendation_feedback)
// cascades away via `on delete cascade` foreign keys in 0001_init.sql -- this
// function's only job is the one thing the client can't do for itself:
// removing the auth.users row, which requires the service-role key.
//
// Deploy with: supabase functions deploy delete-account
// The project's SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are already
// available to every Edge Function automatically; nothing else to configure.

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), { status: 401 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Verify the caller's JWT (as themselves) to learn who they are.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userError } = await callerClient.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });
    }

    // Delete with the service role -- the only key allowed to remove
    // auth.users rows.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userData.user.id);
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), { status: 500 });
  }
});
