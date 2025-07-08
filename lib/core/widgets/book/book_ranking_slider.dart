import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';

import '../../../presentation/screens/book/book_detail_screen.dart';

class BookRankingSlider extends StatelessWidget {
  final List<Map<String, dynamic>> books;

  const BookRankingSlider({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;

    // 3개씩 나누기
    final pages = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < books.length; i += 3) {
      pages.add(books.sublist(i, (i + 3 > books.length) ? books.length : i + 3));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            'Logue 인생 책 실시간 순위',
            style: TextStyle(fontSize: 22, color: AppColors.black900),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            '새로운 인생 책을 로그에서 찾아보세요.',
            style: TextStyle(fontSize: 14, color: AppColors.black500),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 360,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.66),
            itemCount: pages.length,
            padEnds: false, // ✅ 첫 페이지가 왼쪽에 딱 붙게!
            itemBuilder: (context, pageIndex) {
              final pageBooks = pages[pageIndex];

              return Padding(
                padding: const EdgeInsets.only(left: 38, right: 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // ✅ 왼쪽 정렬
                  children: List.generate(pageBooks.length, (i) {
                    final book = pageBooks[i];
                    final rank = pageIndex * 3 + i + 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: GestureDetector(
                        onTap: () {
                          debugPrint('🧪 book map: $book');

                          final bookId = book['book_id'];
                          if (bookId != null && bookId is String) {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => BookDetailScreen(bookId: bookId!),
                            ));
                          } else {
                            debugPrint('❌ 유효한 bookId가 없음: $bookId');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('책 ID가 유효하지 않아요.')),
                            );
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                SizedBox(
                                  width: 71,
                                  height: 100,
                                  child: BookFrame(imageUrl: book['image'] ?? ''),
                                ),
                                Positioned(
                                  bottom: -18,
                                  left: -8,
                                  child: Text(
                                    '$rank',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black45,
                                          offset: Offset(2, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book['title'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book['author'] ?? '',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}