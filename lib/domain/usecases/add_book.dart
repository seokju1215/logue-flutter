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

    for (final book in books) {
      try {
        await client.from('user_books').insert({
          'user_id': user.id,
          'title': book.title,
          'author': book.author,
          'image': book.image,
          'publisher': book.publisher,
        });
      } catch (e) {
        print('! 개별 책 저장 실패: $e');
      }
    }
  }
}