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

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) {
    return new Response("Unauthorized", { status: 401 });
  }

  const followerId = user.id;

  // 팔로우 기록 존재 확인
  const { data: existingFollow } = await supabase
    .from("follows")
    .select("follower_id")
    .eq("follower_id", followerId)
    .eq("following_id", target_user_id)
    .maybeSingle();

  if (!existingFollow) {
    return new Response("Not following", { status: 200 });
  }

  // 삭제
  const { error: deleteError } = await supabase
    .from("follows")
    .delete()
    .eq("follower_id", followerId)
    .eq("following_id", target_user_id);

  if (deleteError) {
    return new Response(deleteError.message, { status: 500 });
  }

  // 프로필 팔로우 수 감소 (RPC 사용)
  await supabase.rpc("decrement_following_count", { user_id_input: followerId });
  await supabase.rpc("decrement_follower_count", { user_id_input: target_user_id });

  return new Response("Unfollowed", { status: 200 });
});