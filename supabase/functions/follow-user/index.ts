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

  if (error || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const followerId = user.id;

  // 중복 확인
  const { data: existingFollow } = await supabase
    .from("follows")
    .select("follower_id")
    .eq("follower_id", followerId)
    .eq("following_id", target_user_id)
    .maybeSingle();

  if (existingFollow) {
    return new Response("Already following", { status: 200 });
  }

  // follow 등록
  const { error: insertError } = await supabase.from("follows").insert({
    follower_id: followerId,
    following_id: target_user_id,
  });

  if (insertError) {
    return new Response(insertError.message, { status: 500 });
  }

  // ✅ 수치 증가: RPC로 대체
  await supabase.rpc("increment_following_count", { user_id: followerId });
  await supabase.rpc("increment_follower_count", { user_id: target_user_id });

  return new Response("Followed", { status: 200 });
});