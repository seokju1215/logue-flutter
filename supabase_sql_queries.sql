-- 1. 목차가 없는 책들 확인
SELECT 
  id,
  title,
  author,
  isbn,
  toc
FROM books 
WHERE toc IS NULL OR toc = ''
ORDER BY created_at DESC;

-- 2. 목차가 없는 책들의 개수 확인
SELECT COUNT(*) as books_without_toc
FROM books 
WHERE toc IS NULL OR toc = '';

-- 3. 알라딘 API를 호출하는 Edge Function 생성 (Supabase Dashboard에서 실행)
-- 이 함수는 Supabase Dashboard > Edge Functions에서 생성해야 합니다.

-- 4. 목차 업데이트를 위한 임시 테이블 생성 (선택사항)
CREATE TABLE IF NOT EXISTS temp_toc_updates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  book_id UUID REFERENCES books(id),
  isbn TEXT,
  title TEXT,
  author TEXT,
  toc TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. 목차가 없는 책들을 임시 테이블에 복사
INSERT INTO temp_toc_updates (book_id, isbn, title, author)
SELECT 
  id,
  isbn,
  title,
  author
FROM books 
WHERE toc IS NULL OR toc = ''
  AND isbn IS NOT NULL 
  AND isbn != '';

-- 6. 임시 테이블에서 목차 업데이트 대상 확인
SELECT * FROM temp_toc_updates ORDER BY created_at DESC;

-- 7. 목차 업데이트 후 임시 테이블 정리
-- DELETE FROM temp_toc_updates;

-- 8. 특정 책의 목차를 수동으로 업데이트 (예시)
UPDATE books 
SET toc = '1장 최악의 생일
2장 도비의 경고
3장 버로
4장 플러리시 앤 블러츠 서점에서
5장 후려치는 버드나무
6장 길더로이 록하트
7장 머드블러드와 속삭임
8장 사망일 파티
9장 벽에 쓰인 글자
10장 불량 블러저
11장 결투 동아리
12장 폴리주스 마법약
13장 아주 비밀스러운 일기장
14장 코닐리어스 퍼지
15장 아라고그
16장 비밀의 방
17장 슬리데린의 후계자
18장 도비가 받은 보상'
WHERE isbn = '9788983928450';

-- 9. 목차 업데이트 현황 확인
SELECT 
  COUNT(*) as total_books,
  COUNT(CASE WHEN toc IS NULL OR toc = '' THEN 1 END) as books_without_toc,
  COUNT(CASE WHEN toc IS NOT NULL AND toc != '' THEN 1 END) as books_with_toc
FROM books;

-- 10. 목차가 있는 책들의 샘플 확인
SELECT 
  title,
  author,
  LEFT(toc, 100) as toc_preview
FROM books 
WHERE toc IS NOT NULL AND toc != ''
ORDER BY created_at DESC
LIMIT 5; 