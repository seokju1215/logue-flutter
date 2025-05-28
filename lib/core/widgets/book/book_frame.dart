import 'package:flutter/material.dart';

class BookFrame extends StatelessWidget {
  final String imageUrl;

  const BookFrame({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('📚 BookFrame: imageUrl = $imageUrl');
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9D9D9), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: imageUrl.isNotEmpty
            ? Image.network(
          imageUrl.startsWith('http://')
              ? imageUrl.replaceFirst('http://', 'https://')
              : imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image),
          ),
        )
            : Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}