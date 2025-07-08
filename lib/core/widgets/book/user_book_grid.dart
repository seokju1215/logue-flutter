import 'package:flutter/material.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';

class UserBookGrid extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final void Function(Map<String, dynamic> book)? onTap;

  const UserBookGrid({
    Key? key,
    required this.books,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return const Center(child: Text('저장된 책이 없습니다.'));
    }

    return SizedBox(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: books.length,
        padding: const EdgeInsets.symmetric(horizontal: 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 23,
          mainAxisSpacing: 30,
          childAspectRatio: 98 / 145,
        ),
        itemBuilder: (context, index) {
          final book = books[index];
          final imageUrl = book['books']?['image'] ?? '';

          return GestureDetector(
            onTap: () {
              if (onTap != null) {
                onTap!(book);
              }
            },
            child: BookFrame(imageUrl: imageUrl ?? ''),
          );
        },
      ),
    );
  }
}