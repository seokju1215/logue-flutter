import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/stroke_text_style.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';

class ArchiveBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books; // 모든 책 목록
  final Function(List<Map<String, dynamic>>)? onBooksUpdated; // 책 목록 업데이트 콜백
  
  const ArchiveBottomSheet({
    super.key,
    required this.books,
    this.onBooksUpdated,
  });

  @override
  State<ArchiveBottomSheet> createState() => _ArchiveBottomSheetState();
}

class _ArchiveBottomSheetState extends State<ArchiveBottomSheet> {
  int selectedBookCount = 0; // 선택된 책 개수를 독립적으로 관리
  List<Map<String, dynamic>> updatedBooks = []; // 업데이트된 책 목록
  
  @override
  void initState() {
    super.initState();
    print('ArchiveBottomSheet 초기화: selectedBookCount = $selectedBookCount');
    
    // 초기화: is_archived가 false인 책들은 이미 선택된 상태로 설정
    updatedBooks = List.from(widget.books);
    for (int i = 0; i < updatedBooks.length; i++) {
      if (updatedBooks[i]['is_archived'] == false) {
        _selected.add(i);
      }
    }
    selectedBookCount = _selected.length;
  }
  
  // 선택 한도
  static const int kMaxSelection = 9;
  
  // 선택 상태
  final Set<int> _selected = {};

  // 선택 토글
  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index)) {
        // 선택 해제: is_archived를 true로, order_index 제거
        _selected.remove(index);
        updatedBooks[index]['is_archived'] = true;
        final removedOrderIndex = updatedBooks[index]['order_index'];
        updatedBooks[index]['order_index'] = null;
        
        // 다른 책들의 order_index를 감소시키기
        if (removedOrderIndex != null) {
          for (int i = 0; i < updatedBooks.length; i++) {
            if (i != index && updatedBooks[i]['order_index'] != null && 
                updatedBooks[i]['order_index'] > removedOrderIndex) {
              updatedBooks[i]['order_index'] = (updatedBooks[i]['order_index'] as int) - 1;
            }
          }
        }
      } else {
        // 선택: is_archived를 false로, order_index를 0으로 설정하고 다른 것들을 1씩 증가
        if (_selected.length >= kMaxSelection) return;
        _selected.add(index);
        updatedBooks[index]['is_archived'] = false;
        
        // 기존에 선택된 책들의 order_index를 1씩 증가
        for (int i = 0; i < updatedBooks.length; i++) {
          if (i != index && updatedBooks[i]['order_index'] != null) {
            updatedBooks[i]['order_index'] = (updatedBooks[i]['order_index'] as int) + 1;
          }
        }
        
        // 새로 선택된 책의 order_index를 0으로 설정
        updatedBooks[index]['order_index'] = 0;
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
                          print('저장 버튼 클릭됨');
                          
                          // 저장 버튼을 눌렀을 때만 업데이트된 책 목록을 상위로 전달
                          if (widget.onBooksUpdated != null) {
                            widget.onBooksUpdated!(updatedBooks);
                          }
                          
                          // 바텀시트 닫기는 것은 onBooksUpdated 콜백에서 처리
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
                                          child: ColorFiltered(
                                            colorFilter: isSelected 
                                                ? ColorFilter.mode(
                                                    Colors.black.withOpacity(0.6),
                                                    BlendMode.darken,
                                                  )
                                                : ColorFilter.mode(
                                                    Colors.transparent,
                                                    BlendMode.srcOver,
                                                  ),
                                            child: BookFrame(
                                              imageUrl: imageUrl,
                                            ),
                                          ),
                                        ),
                                        // 선택 인디케이터 - Align을 사용하여 안정적인 위치에 배치
                                        Align(
                                          alignment: Alignment.topRight,
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 3.24, top: 3),
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected ? AppColors.blue500 : AppColors.black300,
                                                width: isSelected ? 2 : 1.5,
                                              ),
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 50),
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? AppColors.blue500 : Colors.transparent,
                                              ),
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
