import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../data/models/inquiry_models.dart';
import '../../../../data/repositories/inquiry_repository.dart';
import '../../../../data/datasources/inquiry_api.dart';

class InquiryScreen extends StatefulWidget {
  const InquiryScreen({Key? key}) : super(key: key);

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  late Future<List<Map<String, dynamic>>> _futureInquiries;

  @override
  void initState() {
    super.initState();
    _loadInquiries();
  }

  void _loadInquiries() {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    
    if (currentUser == null) {
      // 사용자가 로그인하지 않은 경우 처리
      setState(() {
        _futureInquiries = Future.value([]);
      });
      return;
    }

    final userId = currentUser.id;
    final api = InquiryApi(client);
    final repository = InquiryRepository(api);
    
    setState(() {
      _futureInquiries = repository.getInquiries(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('고객센터 / 소통', style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,),),
          centerTitle: true,
          leading: IconButton(
            icon: SvgPicture.asset('assets/back_arrow.svg'),
            onPressed: () => Navigator.pop(context),
          ),
        ),
    );
  }
}
