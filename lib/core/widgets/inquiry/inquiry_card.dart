import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';

class InquiryCard extends StatelessWidget {
  final String userId;
  final String request;
  final String details;
  final String date;
  final String status;

  const InquiryCard({
    Key? key,
    required this.userId,
    required this.request,
    required this.details,
    required this.date,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD9D9D9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userId,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w400,
              color: AppColors.black500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            request,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.black900,
              height: 1.23
            ),
          ),
          const SizedBox(height: 5),
          Text(
            details,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              color: AppColors.black500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            date,
            style: const TextStyle(
              fontSize: 10,
              height: 1.2,
              color: AppColors.black500,
            ),
          ),
        ],
      ),
    );
  }
}
