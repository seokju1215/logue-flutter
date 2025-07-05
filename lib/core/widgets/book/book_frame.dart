import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:logue/core/themes/app_colors.dart';

class BookFrame extends StatelessWidget {
  final String imageUrl;

  const BookFrame({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final safeUrl = imageUrl.startsWith('http://')
        ? imageUrl.replaceFirst('http://', 'https://')
        : imageUrl;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.black300, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
          imageUrl: safeUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
          ),
          errorWidget: (context, url, error) => Container(
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