import 'package:flutter/material.dart';

class PostPopupMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PostPopupMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Text('내용 수정'),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
      icon: const Icon(Icons.more_vert, color: Colors.black),
    );
  }
}