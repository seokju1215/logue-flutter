import 'package:flutter/material.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';

class JobEdit extends StatefulWidget {
  final String currentJob;

  const JobEdit({super.key, required this.currentJob});

  @override
  State<JobEdit> createState() => _JobEditState();
}

class _JobEditState extends State<JobEdit> {
  final client = Supabase.instance.client;
  late TextEditingController _controller;
  String? searchKeyword;

  bool hasChanged = false;
  bool isValid = true;
  List<Map<String, dynamic>> suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentJob);
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _controller.text.trim();
    final changed = text != widget.currentJob;

    setState(() {
      hasChanged = changed;
      isValid = text.isNotEmpty && text.length <= 20;
    });
  }

  /// ✅ 검색 버튼 눌렀을 때만 추천 호출
  void _onSearch() {
    final keyword = _controller.text.trim();
    setState(() {
      searchKeyword = keyword; // ✅ 검색어 확정
    });
    _fetchJobSuggestions(keyword);
  }


  void _onConfirm([String? selectedJob]) {
    final jobToSave = selectedJob ?? _controller.text.trim();

    if (jobToSave == widget.currentJob || jobToSave.isEmpty || jobToSave.length > 20) return;

    try {
      Navigator.pop(context, {'job': jobToSave});
    } catch (e) {
      debugPrint('❌ JobEdit 네비게이션 오류: $e');
      // 에러 발생 시에도 안전하게 돌아가기
      Navigator.of(context).pop({'job': jobToSave});
    }
  }


  Future<void> _fetchJobSuggestions(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => suggestions = []);
      return;
    }

    try {
      final response = await client
          .from('job_tags')
          .select()
          .ilike('job_name', '%$keyword%') // 부분 일치 검색
          .order('user_count', ascending: false)
          .limit(20);

      final data = response as List;
      setState(() {
        suggestions = data.map((e) {
          return {
            'job': e['job_name'],
            'count': e['user_count'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('직업 추천 가져오기 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmEnabled = hasChanged && isValid;

    Color borderColor = AppColors.black500;
    if (_controller.text.isNotEmpty) {
      if (!isValid) {
        borderColor = AppColors.red500;
      } else if (hasChanged) {
        borderColor = AppColors.blue500;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('직업', style: TextStyle(color: AppColors.black900, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: isConfirmEnabled ? _onConfirm : null,
            child: Text(
              '확인',
              style: TextStyle(
                color: isConfirmEnabled ? AppColors.blue500 : AppColors.black300,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              onSubmitted: (_) => _onSearch(),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: AppColors.black900),
            ),
            const SizedBox(height: 6),
            const Text(
              '실제 직업, 활동 분야 또는 대표하는 역할 등을 입력하여\n사람들이 직업을 알 수 있도록 해주세요.',
              style: TextStyle(fontSize: 12, color: AppColors.black500),
            ),
            if (_controller.text.isNotEmpty)
              if (searchKeyword != null && searchKeyword!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 9, bottom: 8),
                  child: Text('"$searchKeyword" 검색결과', style: const TextStyle(fontSize: 12)),
                ),
            Expanded(
              child: ListView.builder(
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final item = suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _onConfirm(item['job']),
                      child: Row(
                        children: [
                          // 해시 아이콘 (둥근 배경)
                          SvgPicture.asset(
                            'assets/hashtag_icon.svg', // 네가 말한 원 포함된 SVG 경로
                            width: 36,
                            height: 36,
                          ),
                          const SizedBox(width: 22),

                          // 텍스트 영역
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['job'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.black900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item['count']}명 사용',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.black500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}