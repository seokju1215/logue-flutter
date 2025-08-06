import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/presentation/screens/setting/legal_notice/ecommerce_disclosure_screen.dart';
import 'package:my_logue/presentation/screens/setting/legal_notice/payment_and_refund_screen.dart';
import 'package:my_logue/presentation/screens/setting/legal_notice/privacy_policy.dart';
import 'package:my_logue/presentation/screens/setting/legal_notice/terms_of_service_screen.dart';

import '../../../../core/themes/app_colors.dart';

class LegalNoticeScreen extends StatefulWidget {
  const LegalNoticeScreen({Key? key}) : super(key: key);

  @override
  State<LegalNoticeScreen> createState() => _LegalNoticeScreenState();
}

class _LegalNoticeScreenState extends State<LegalNoticeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '법적 고지사항',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.black900,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton(onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => PrivacyPolicy(),
                ),
              );
            },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero, // ❗️최소 크기 제거
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ❗️터치 영역 축소
                alignment: Alignment.centerLeft,
              ),
              child: Text('개인정보 처리방침', style: TextStyle(color: AppColors.black900, fontSize: 14, height: 1.21),),),
            SizedBox(height: 31,),
            TextButton(onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => TermsOfServiceScreen(),
                ),
              );
            },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero, // ❗️최소 크기 제거
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ❗️터치 영역 축소
                alignment: Alignment.centerLeft,
              ),
              child: Text('이용약관', style: TextStyle(color: AppColors.black900, fontSize: 14, height: 1.21),),),
            SizedBox(height: 31,),
            TextButton(onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => LegalNoticeScreen(),
                ),
              );
            },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero, // ❗️최소 크기 제거
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ❗️터치 영역 축소
                alignment: Alignment.centerLeft,
              ),
              child: Text('사업자정보', style: TextStyle(color: AppColors.black900, fontSize: 14, height: 1.21),),),
            SizedBox(height: 31,),
            TextButton(onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => PaymentAndRefundScreen(),
                ),
              );
            },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero, // ❗️최소 크기 제거
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ❗️터치 영역 축소
                alignment: Alignment.centerLeft,
              ),
              child: Text('결제 및 환불 정보', style: TextStyle(color: AppColors.black900, fontSize: 14, height: 1.21),),),
            SizedBox(height: 31,),
            TextButton(onPressed: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => EcommerceDisclosureScreen(),
                ),
              );
            },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero, // ❗️최소 크기 제거
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // ❗️터치 영역 축소
                alignment: Alignment.centerLeft,
              ),
              child: Text('통신판매업 고지사항', style: TextStyle(color: AppColors.black900, fontSize: 14, height: 1.21),),),
            SizedBox(height: 31,)
          ],
        ),
      )
    );
  }
}
