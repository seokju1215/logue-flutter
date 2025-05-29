import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  );

  const { target_user_id } = await req.json();
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "");

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);

  if (!target_user_id) {
    return new Response(JSON.stringify({ error: "target_user_id is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (error || !user) {
    return new Response(JSON.stringify({ isFollowing: false }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const followerId = user.id;

  const { data: existingFollow } = await supabase
    .from("follows")
    .select("follower_id")
    .eq("follower_id", followerId)
    .eq("following_id", target_user_id)
    .maybeSingle();

  return new Response(
    JSON.stringify({ isFollowing: !!existingFollow }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    }
  );
});