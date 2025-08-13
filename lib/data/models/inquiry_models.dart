class InquiryModel {
  final String id;
  final String userId;
  final String username;
  final String title;
  final String content;
  final String inquiryType;
  final String? email;
  final bool isCompleted;
  final DateTime createdAt;

  InquiryModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.title,
    required this.content,
    required this.inquiryType,
    required this.email,
    required this.isCompleted,
    required this.createdAt,
  });

  factory InquiryModel.fromMap(Map<String, dynamic> map) {
    return InquiryModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      inquiryType: map['inquiry_type'] as String,
      email: map['email'] as String?,
      isCompleted: map['is_completed'] as bool,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'title': title,
      'content': content,
      'inquiry_type': inquiryType,
      'email': email,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class InquiryListModel {
  final String id;
  final String userId;
  final String username;
  final String title;
  final String content;
  final String inquiryType;
  final DateTime createdAt;

  InquiryListModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.title,
    required this.content,
    required this.inquiryType,
    required this.createdAt,
  });

  factory InquiryListModel.fromMap(Map<String, dynamic> map) {
    return InquiryListModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      inquiryType: map['inquiry_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'title': title,
      'content': content,
      'inquiry_type': inquiryType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedDate {
    final year = createdAt.year;
    final month = createdAt.month.toString().padLeft(2, '0');
    final day = createdAt.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}