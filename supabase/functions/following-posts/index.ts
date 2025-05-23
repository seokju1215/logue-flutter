// functions/following-posts/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const supabase = createClient(supabaseUrl, supabaseKey)

  const authHeader = req.headers.get('Authorization')
  const token = authHeader?.replace('Bearer ', '')

  if (!token) {
    return new Response('Unauthorized', { status: 401 })
  }

  const {
    data: {
      user: { id: currentUserId },
    },
    error: userError,
  } = await supabase.auth.getUser(token)

  if (userError || !currentUserId) {
    return new Response('Unauthorized', { status: 401 })
  }

  // 1. 현재 사용자가 팔로우 중인 사용자 목록 조회
  const { data: followingList, error: followsError } = await supabase
    .from('follows')
    .select('following_id')
    .eq('follower_id', currentUserId)

  if (followsError) {
    return new Response(JSON.stringify({ error: followsError.message }), { status: 500 })
  }

  const followingIds = followingList.map((row) => row.following_id)

  if (followingIds.length === 0) {
    return new Response(JSON.stringify([]), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  }

  // 2. 팔로잉한 사용자의 책 후기 최신순 조회
  const { data: posts, error: postsError } = await supabase
    .from('book_posts')
    .select('*')
    .in('user_id', followingIds)
    .order('created_at', { ascending: false })

  if (postsError) {
    return new Response(JSON.stringify({ error: postsError.message }), { status: 500 })
  }

  return new Response(JSON.stringify(posts), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})