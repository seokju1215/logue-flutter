import 'package:my_logue/data/datasources/inquiry_api.dart';

class InquiryRepository {
  final InquiryApi api;

  InquiryRepository(this.api);

  Future<List<Map<String, dynamic>>> getInquiries(String userId) {
    return api.fetchInquiries(userId);
  }
}