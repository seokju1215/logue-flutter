import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/stroke_text_style.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';

class ArchiveBottomSheet extends StatefulWidget {
  final Function(bool)? onClose; // 닫기 콜백, 결과값 전달
  final List<Map<String, dynamic>> books; // 보관함 책 목록
  
  const ArchiveBottomSheet({
    super.key,
    this.onClose,
    required this.books,
  });

  @override
  State<ArchiveBottomSheet> createState() => _ArchiveBottomSheetState();
}

class _ArchiveBottomSheetState extends State<ArchiveBottomSheet> {
  int selectedBookCount = 0; // 선택된 책 개수를 독립적으로 관리
  
  @override
  void initState() {
    super.initState();
    print('ArchiveBottomSheet 초기화: selectedBookCount = $selectedBookCount');
  }
  // 선택 한도
  static const int kMaxSelection = 9;

// 실제 책 데이터 사용

// 선택 상태
  final Set<int> _selected = {};

// 선택 토글
  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        if (_selected.length >= kMaxSelection) return;
        _selected.add(index);
      }
      selectedBookCount = _selected.length; // 상단 카운트 연동
    });
  }

  /// 책장(선반) 라인들 생성
  List<Widget> _buildShelves({
    required int itemCount,
    required double itemHeight,
    required double runSpacing,
    required double topOffset,
  }) {
    const booksPerRow = 5;
    final rowCount = (itemCount / booksPerRow).ceil();

    return List.generate(rowCount, (i) {
      final shelfTop = topOffset + (itemHeight + runSpacing) * i;
      return Positioned(
        top: shelfTop,
        left: 0,
        right: 0,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    print('ArchiveBottomSheet 빌드: selectedBookCount = $selectedBookCount');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.black300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 제목과 저장 버튼
          Container(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 15),
            child: Stack(
              children: [
                // 보관함 제목 (정가운데)
                Center(
                  child: Text(
                    '보관함',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.black900,
                      fontWeight: FontWeight.w400,
                      height: 1.1875
                    ),
                  ),
                ),
                // 저장 버튼 (Positioned로 오른쪽에 배치)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // TODO: 선택된 책들을 저장하는 로직 구현
                          print('저장 버튼 클릭됨');
                          if (widget.onClose != null) {
                            widget.onClose!(true); // 책 추가 완료 시 true 반환
                          }
                        },
                        child: Text(
                          '저장',
                          style: TextStyle(
                            color: AppColors.blue500,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$selectedBookCount/9',
                        style: TextStyle(
                          color: AppColors.black900, // 더 진한 색상으로 변경
                          fontSize: 14, // 폰트 크기 증가
                          fontWeight: FontWeight.w500, // 폰트 굵기 증가
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 보관함 책 목록 (예시)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 10,),
                                    Text(
                  '${widget.books.length}/9',
                  style: const TextStyle(fontSize: 12, color: AppColors.black500, height: 1.25),
                ),
                  ],
                ),
                SizedBox(height: 8,),
              ],
            ),
          ),

          // ⬇️ 그리드 섹션만 스크롤되도록 교체
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0).copyWith(top: 21, bottom: 21),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 디자인 파라미터
                  const crossAxisCount = 5;
                  const crossAxisSpacing = 11.7;
                  const runSpacing = 35.0;
                  const itemAspectRatio = 98 / 145;
                  const topOffsetForShelf = 90.0; // 선반 시작 오프셋

                  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                  final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
                  final itemHeight = itemWidth / itemAspectRatio;

                  final rows = (widget.books.length / crossAxisCount).ceil();
                  final gridHeight = rows * itemHeight + (rows - 1) * runSpacing;

                  return Scrollbar(
                    child: SingleChildScrollView(
                      // ✅ 오직 이 영역만 스크롤
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: gridHeight + topOffsetForShelf, // 선반 포함 전체 높이
                        width: double.infinity,
                        child: Stack(
                          children: [
                            // 선반 라인들 (그리드와 함께 스크롤)
                            ..._buildShelves(
                              itemCount: widget.books.length,
                              itemHeight: itemHeight,
                              runSpacing: runSpacing,
                              topOffset: topOffsetForShelf,
                            ),

                            // 책 그리드
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: GridView.builder(
                                // 🔒 내부 그리드는 스크롤 금지 — 바깥 SingleChildScrollView가 담당
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: widget.books.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisSpacing: runSpacing,
                                  childAspectRatio: itemAspectRatio,
                                ),
                                itemBuilder: (context, index) {
                                  final book = widget.books[index];
                                  final imageUrl = book['books']?['image'] ?? 'https://via.placeholder.com/150';
                                  final isSelected = _selected.contains(index);

                                  return GestureDetector(
                                    onTap: () => _toggleSelect(index),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // 책 커버
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(0),
                                          child: BookFrame(
                                            imageUrl: imageUrl,
                                          ),
                                        ),
                                        // 선택 인디케이터
                                        Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? AppColors.blue500 : AppColors.black100,
                                                width: isSelected ? 3 : 2,
                                              ),
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              margin: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? AppColors.blue500 : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          )

        ],
      ),
    );
  }
}
