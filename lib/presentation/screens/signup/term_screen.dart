import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/widgets/common/circle_checkbox.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool allAgreed = false;
  bool agreedTerms = false;
  bool agreedPrivacy = false;
  bool isLoading = false;

  void _toggleAll(bool? value) {
    final checked = value ?? false;
    setState(() {
      allAgreed = checked;
      agreedTerms = checked;
      agreedPrivacy = checked;
    });
  }
  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('❌ $url 열기 실패');
    }
  }

  void _toggleIndividual({
    bool? terms,
    bool? privacy,
  }) {
    setState(() {
      if (terms != null) agreedTerms = terms;
      if (privacy != null) agreedPrivacy = privacy;

      allAgreed = agreedTerms && agreedPrivacy;
    });
  }

  Future<void> _submit() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (!agreedTerms || !agreedPrivacy) return;

    setState(() => isLoading = true);
    await Supabase.instance.client.from('user_agreements').insert({
      'user_id': user.id,
      'agreed_terms': agreedTerms,
      'agreed_privacy': agreedPrivacy,
      'agreed_at': DateTime.now().toIso8601String(),
    });

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/select-3books');
    }
  }

  Widget _buildCheckItem({
    required bool value,
    required Function(bool?) onChanged,
    required String text,
    void Function()? onTap,
  }) {
    return InkWell(
      onTap: () {
        onChanged(!value); // ✅ 텍스트/체크박스 누르면 동의 체크
      },
      borderRadius: BorderRadius.circular(8),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleCheckbox(
              value: value,
              onChanged: (v) => onChanged(v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (onTap != null)
              GestureDetector(
                onTap: onTap, // 🔗 아이콘 눌렀을 때만 링크 이동
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmed = agreedTerms && agreedPrivacy;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              Center(
                child: SvgPicture.asset(
                  'assets/logue_logo_with_title.svg', // SVG 파일 경로
                  height: 64,
                ),
              ),
              const SizedBox(height: 40),

              _buildCheckItem(
                value: allAgreed,
                onChanged: _toggleAll,
                text: '약관 전체 동의',
              ),
              const SizedBox(height: 10),
              const Divider(thickness: 2,),

              _buildCheckItem(
                value: agreedTerms,
                onChanged: (v) => _toggleIndividual(terms: v),
                text: '(필수) 서비스 이용약관 동의',
                onTap: () => _launchUrl('https://general-spatula-561.notion.site/2024e6fb980480daadd6cd8bafe388a9'),
              ),
              _buildCheckItem(
                value: agreedPrivacy,
                onChanged: (v) => _toggleIndividual(privacy: v),
                text: '(필수) 개인정보 수집 및 이용 동의',
                onTap: () => _launchUrl('https://general-spatula-561.notion.site/2024e6fb980480efa65acb5c7e330be5'),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isConfirmed && !isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConfirmed ? Colors.black : Colors.grey[300],
                    foregroundColor: isConfirmed ? Colors.white : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}