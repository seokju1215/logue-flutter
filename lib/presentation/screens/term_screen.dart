import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/repositories/agreement_repository.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agreedTerms = false;
  bool _agreedPrivacy = false;
  bool _isLoading = false;

  Future<void> _submitAgreement() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (!_agreedTerms || !_agreedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목에 동의해야 합니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.from('user_agreements').insert({
        'user_id': user.id,
        'agreed_terms': _agreedTerms,
        'agreed_privacy': _agreedPrivacy,
        'agreed_at': DateTime.now().toIso8601String(),
      });

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류 발생: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildCheckboxTile({
    required String title,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('약관 동의'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '서비스 이용을 위해 아래 항목에 동의해 주세요.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildCheckboxTile(
              title: '이용약관에 동의합니다.',
              value: _agreedTerms,
              onChanged: (val) => setState(() => _agreedTerms = val ?? false),
            ),
            _buildCheckboxTile(
              title: '개인정보 처리방침에 동의합니다.',
              value: _agreedPrivacy,
              onChanged: (val) => setState(() => _agreedPrivacy = val ?? false),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitAgreement,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('동의하고 시작하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}