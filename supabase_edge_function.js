// Supabase Edge Function: update-book-toc
// Supabase Dashboard > Edge Functions에서 새 함수 생성 후 이 코드를 붙여넣기

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS 처리
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Supabase 클라이언트 생성
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 1. 목차가 없는 책들 조회
    const { data: booksWithoutToc, error: fetchError } = await supabase
      .from('books')
      .select('id, isbn, title, author')
      .or('toc.is.null,toc.eq.')
      .not('isbn', 'is', null)
      .not('isbn', 'eq', '')

    if (fetchError) {
      throw new Error(`책 조회 실패: ${fetchError.message}`)
    }

    console.log(`목차가 없는 책 ${booksWithoutToc.length}개 발견`)

    let updatedCount = 0
    let errorCount = 0

    // 2. 각 책에 대해 알라딘 API 호출
    for (const book of booksWithoutToc) {
      try {
        // 알라딘 API 호출 (ItemLookUp - 상세조회)
        const aladinUrl = `http://www.aladin.co.kr/ttb/api/ItemLookUp.aspx`
        const params = new URLSearchParams({
          ttbkey: 'YOUR_ALADIN_API_KEY', // 실제 API 키로 교체 필요
          itemIdType: 'ISBN13',
          ItemId: book.isbn,
          Output: 'XML',
          Version: '20131101'
        })

        const response = await fetch(`${aladinUrl}?${params}`)
        const xmlText = await response.text()

        // XML 파싱 (간단한 방법)
        let toc = ''
        
        // 목차 정보 추출 (XML에서 toc 태그 찾기)
        const tocMatch = xmlText.match(/<toc>(.*?)<\/toc>/s)
        if (tocMatch && tocMatch[1]) {
          toc = tocMatch[1].trim()
        }

        // 목차가 있으면 DB 업데이트
        if (toc && toc.length > 10) {
          const { error: updateError } = await supabase
            .from('books')
            .update({ toc: toc })
            .eq('id', book.id)

          if (updateError) {
            console.error(`책 ${book.title} 업데이트 실패:`, updateError)
            errorCount++
          } else {
            console.log(`✅ ${book.title} 목차 업데이트 완료`)
            updatedCount++
          }
        } else {
          console.log(`⚠️ ${book.title} - 목차 정보 없음`)
        }

        // API 호출 간격 조절 (초당 1회)
        await new Promise(resolve => setTimeout(resolve, 1000))

      } catch (error) {
        console.error(`책 ${book.title} 처리 중 오류:`, error)
        errorCount++
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `목차 업데이트 완료`,
        total: booksWithoutToc.length,
        updated: updatedCount,
        errors: errorCount
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
}) 