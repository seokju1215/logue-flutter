import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/book_model.dart';

class AddBookUseCase {
  final SupabaseClient client;

  AddBookUseCase(this.client);

  Future<void> call(List<BookModel> books) async {
    final user = client.auth.currentUser;
    if (user == null) {
      print('❌ 로그인된 사용자 없음');
      return;
    }

    for (int i = 0; i < books.length; i++) {
      final book = books[i];

      // books 테이블에 이미 있는지 확인
      final existing = await client
          .from('books')
          .select('isbn')
          .eq('isbn', book.isbn)
          .maybeSingle();

      if (existing == null) {
        try {
          await client.from('books').insert(book.toBookMap());
        } catch (e) {
          print('❌ books 테이블 insert 실패: $e');
        }
      }

      try {
        await client.from('user_books').insert({
          'user_id': user.id,
          'isbn': book.isbn,
          'order_index': i,
          'review_title': '',
          'review_content': '',
        });
      } catch (e) {
        print('❌ user_books 테이블 insert 실패: $e');
      }
    }
  }
}