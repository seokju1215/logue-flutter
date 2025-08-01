import 'package:my_logue/data/repositories/inquiry_repository.dart';

class FetchUserInquiries {
  final InquiryRepository repository;

  FetchUserInquiries(this.repository);

  Future<List<Map<String, dynamic>>> call(String userId) {
    return repository.getInquiries(userId);
  }
}