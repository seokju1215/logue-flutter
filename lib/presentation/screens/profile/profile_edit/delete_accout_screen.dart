import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  int? selectedReasonIndex;
  bool agreed = false;
  final TextEditingController _controller = TextEditingController();

  final List<String> reasons = [
    '원하는 책이 서비스에 없어서',
    '인생 책을 9권밖에 설정할 수 없어서',
    '앱이 느리거나 오류가 많아서',
    '팔로우/댓글/좋아요 등 소통이 없어서',
    '독서 기록용으로 쓰기 부족해서',
    '사용빈도가 낮아서',
    '재밌는 콘텐츠가 없어서',
    '기타',
  ];

  void _onSubmit() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isOtherSelected = selectedReasonIndex == reasons.length - 1;
    final bool canSubmit = selectedReasonIndex != null && agreed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('계정 탈퇴'),
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말 계정을 탈퇴하시겠어요?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('한 번 더 생각해 보지 않으시겠어요?', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            const Text(
              '계정을 탈퇴하시려는 이유를 말씀해주세요. 제품 개선에 중요자료로 활용할게요.',
              style: TextStyle(fontSize: 12, color: AppColors.black500),
            ),
            const SizedBox(height: 10),

            // 🔹 탈퇴 사유 선택
            for (int i = 0; i < reasons.length; i++)
              RadioListTile(
                title: Text(reasons[i], style: const TextStyle(fontSize: 14)),
                value: i,
                groupValue: selectedReasonIndex,
                onChanged: (int? value) {
                  setState(() => selectedReasonIndex = value);
                },
              ),

            // 🔹 기타 선택 시 입력창
            if (isOtherSelected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '기타 내용을 입력해주세요.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            const Text(
              '계정 탈퇴 유의사항 (반드시 확인해 주세요)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '계정을 탈퇴 후 30일이 지나면 계정이 완전히 삭제되며, 삭제된 정보는 복구가 불가합니다.\n\n'
                  '30일 이내에 해당 구글 계정으로 로그인 시 계정 탈퇴가 취소됩니다.',
              style: TextStyle(fontSize: 12, color: AppColors.black500),
            ),

            const SizedBox(height: 20),
            CheckboxListTile(
              value: agreed,
              onChanged: (value) =>
                  setState(() => agreed = value ?? false),
              title: const Text('위 내용을 모두 이해하고 동의합니다.',
                  style: TextStyle(fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 24),

            // 🔺 이제 버튼도 스크롤 가능 영역에 포함됨
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _onSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  canSubmit ? Colors.red : Colors.red.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('계정탈퇴', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 32), // 충분한 하단 여백
          ],
        ),
      ),
    );
  }
}
