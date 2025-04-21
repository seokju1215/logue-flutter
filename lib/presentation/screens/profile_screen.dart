import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: SvgPicture.asset('assets/bell_icon.svg'),
          onPressed: () {
            Navigator.pushNamed(context, '/notification');
          },
        ),
        title: const Text(
          'asdfadsf', // 나중에 동적으로 사용자 이름 넣어도 돼
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: SvgPicture.asset('assets/edit_icon.svg'),
            onPressed: () {
              Navigator.pushNamed(context, '/profile_edit');
            },
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text('프로필 화면 내용'),
      ),
    );
  }
}
