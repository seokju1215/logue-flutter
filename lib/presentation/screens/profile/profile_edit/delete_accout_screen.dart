import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    '독서 기록용으로 쓰기 부적합해서',
    '사용빈도가 낮아서',
    '재밌는 콘텐츠가 없어서',
    '기타',
  ];

  Future<void> _onSubmit() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final reasonText = (selectedReasonIndex == reasons.length - 1)
        ? _controller.text
        : '';

    try {
      // 🔹 1. 탈퇴 사유 저장
      await client.from('delete_feedback').insert({
        'email': user.email,
        'reason_index': selectedReasonIndex,
        'reason_text': reasonText,
      });
      await client.auth.signOut();

      // 🔹 2. 계정 삭제 Edge Function 호출
      final res = await client.functions.invoke('delete_account', body: {
        'userId': user.id,
        'email' : user.email,
      });

      debugPrint('📡 계정 삭제 결과: ${res.status}, ${res.data}');

      if (res.status == 200 && res.data['success'] == true) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정 삭제에 실패했습니다.')),
        );
      }
    } catch (e) {
      debugPrint('❌ 탈퇴 처리 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('탈퇴 처리 중 문제가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isOtherSelected = selectedReasonIndex == reasons.length - 1;
    final bool canSubmit = selectedReasonIndex != null && agreed;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '계정 탈퇴',
          style: TextStyle(fontSize: 16, color: AppColors.black900),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정말 계정을 탈퇴하시겠어요?\n한 번 더 생각해 보지 않으시겠어요?',
                style: TextStyle(fontSize: 16, color: AppColors.black900)),
            const SizedBox(height: 10),
            const Text(
              '계정을 탈퇴하시려는 이유를 말씀해주세요. 제품 개선에 중요자료로 활용할게요.',
              style: TextStyle(fontSize: 14, color: AppColors.black500),
            ),
            const SizedBox(height: 10),

            for (int i = 0; i < reasons.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                    unselectedWidgetColor: AppColors.black300,
                  ),
                  child: RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      reasons[i],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.black900,
                      ),
                    ),
                    activeColor: AppColors.black900,
                    value: i,
                    groupValue: selectedReasonIndex,
                    onChanged: (int? value) {
                      setState(() {
                        selectedReasonIndex =
                        (selectedReasonIndex == value) ? null : value;
                      });
                    },
                  ),
                ),
              ),

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
            const Center(
              child: Text(
                '계정 탈퇴 유의사항 (반드시 확인해 주세요)\n\n'
                    '탈퇴 즉시 계정 및 모든 데이터가\n완전히 삭제되며 복구가 불가능합니다.\n\n'
                    '탈퇴에 사용된 구글 계정은 14일간\n재가입에 사용할 수 없습니다.',
                style: TextStyle(fontSize: 12, color: AppColors.black500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                setState(() => agreed = !agreed);
              },
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: agreed ? true : null,
                    onChanged: null,
                    activeColor: AppColors.black900,
                    visualDensity:
                    const VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '위 내용을 모두 이해하고 동의합니다.',
                      style: TextStyle(fontSize: 14, color: AppColors.black900),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 17),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _onSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  canSubmit ? AppColors.red500 : AppColors.red500.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('계정탈퇴', style: TextStyle(fontSize: 14,color: AppColors.white500)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}