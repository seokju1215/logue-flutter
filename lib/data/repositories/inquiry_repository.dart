import 'package:my_logue/data/datasources/inquiry_api.dart';
import 'package:my_logue/data/models/inquiry_models.dart';

class InquiryRepository {
  final InquiryApi api;

  InquiryRepository(this.api);

  Future<List<Map<String, dynamic>>> getInquiries(String userId) {
    return api.fetchInquiries(userId);
  }

  Future<List<InquiryListModel>> getAllInquiries() async {
    final data = await api.fetchAllInquiries();
    return data.map((map) => InquiryListModel.fromMap(map)).toList();
  }

  Future<List<InquiryListModel>> getCompletedInquiries() async {
    final data = await api.fetchCompletedInquiries();
    return data.map((map) => InquiryListModel.fromMap(map)).toList();
  }

  Future<List<InquiryListModel>> getPendingInquiries() async {
    final data = await api.fetchPendingInquiries();
    return data.map((map) => InquiryListModel.fromMap(map)).toList();
  }
}