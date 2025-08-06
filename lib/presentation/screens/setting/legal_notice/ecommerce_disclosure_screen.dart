import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/themes/app_colors.dart';

class EcommerceDisclosureScreen extends StatefulWidget {
  const EcommerceDisclosureScreen({Key? key}) : super(key: key);

  @override
  State<EcommerceDisclosureScreen> createState() => _EcommerceDisclosureScreenState();
}

class _EcommerceDisclosureScreenState extends State<EcommerceDisclosureScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          '결제 및 환불정보',
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
    );
  }
}
