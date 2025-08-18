import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';

class ArchiveBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> books; // 바텀시트 오픈 시점의 스냅샷
  final Function(List<Map<String, dynamic>>)? onBooksUpdated; // 저장 시에만 호출
  final VoidCallback? onClose; // 완전히 닫을 때만 호출

  const ArchiveBottomSheet({
    super.key,
    required this.books,
    this.onBooksUpdated,
    this.onClose,
  });

  @override
  State<ArchiveBottomSheet> createState() => _ArchiveBottomSheetState();
}

class _ArchiveBottomSheetState extends State<ArchiveBottomSheet> {
  late List<Map<String, dynamic>> updatedBooks; // 화면 내부 작업용(원본 불변)
  final Set<int> _selected = {};
  static const int kMaxSelection = 9;
  int selectedBookCount = 0;

  @override
  void initState() {
    super.initState();
    _resetFrom(widget.books); // 오픈 시점 스냅샷으로만 초기화
  }

  // ✅ 바텀시트 열려있는 동안에는 외부 리빌드로 초기화하지 않음
  // @override
  // void didUpdateWidget(covariant ArchiveBottomSheet oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   // 초기화 금지: 완전히 닫힐 때만 초기화
  // }

  void _resetFrom(List<Map<String, dynamic>> source) {
    updatedBooks = source.map((m) => Map<String, dynamic>.from(m)).toList();
    
    // 디버깅: _resetFrom에서 받은 데이터 구조 확인
    debugPrint('🔍 _resetFrom - 받은 데이터 구조:');
    for (int i = 0; i < updatedBooks.length; i++) {
      final book = updatedBooks[i];
      debugPrint('  [$i] ID: ${book['id']}, book_id: ${book['book_id']}, is_archived: ${book['is_archived']}');
    }
    
    _selected.clear();
    for (int i = 0; i < updatedBooks.length; i++) {
      if (updatedBooks[i]['is_archived'] == false) _selected.add(i);
    }
    selectedBookCount =
        updatedBooks.where((b) => b['is_archived'] == false).length;
    setState(() {});
  }

  void _toggleSelect(int index) {
    // 디버깅: 선택 전 데이터 구조 확인
    debugPrint('🔍 _toggleSelect 시작 - index: $index');
    debugPrint('🔍 선택 전 updatedBooks[$index]: ID=${updatedBooks[index]['id']}, book_id=${updatedBooks[index]['book_id']}, is_archived=${updatedBooks[index]['is_archived']}');
    
    setState(() {
      final currentSelected =
          updatedBooks.where((b) => b['is_archived'] == false).length;

      if (_selected.contains(index)) {
        _selected.remove(index);
        updatedBooks[index]['is_archived'] = true;

        final removedOrderIndex = updatedBooks[index]['order_index'];
        updatedBooks[index]['order_index'] = null;

        if (removedOrderIndex != null) {
          for (int i = 0; i < updatedBooks.length; i++) {
            if (i == index) continue;
            final oi = updatedBooks[i]['order_index'];
            if (oi != null && oi is int && oi > removedOrderIndex) {
              updatedBooks[i]['order_index'] = oi - 1;
            }
          }
        }
      } else {
        if (currentSelected >= kMaxSelection) return;

        _selected.add(index);
        updatedBooks[index]['is_archived'] = false;

        for (int i = 0; i < updatedBooks.length; i++) {
          if (i == index) continue;
          final oi = updatedBooks[i]['order_index'];
          if (oi != null && oi is int) {
            updatedBooks[i]['order_index'] = oi + 1;
          }
        }
        updatedBooks[index]['order_index'] = 0;
      }

      selectedBookCount =
          updatedBooks.where((b) => b['is_archived'] == false).length;
      
      // 디버깅: 선택 후 데이터 구조 확인
      debugPrint('🔍 선택 후 updatedBooks[$index]: ID=${updatedBooks[index]['id']}, book_id=${updatedBooks[index]['book_id']}, is_archived=${updatedBooks[index]['is_archived']}');
    });
  }

  List<Widget> _buildShelves({
    required int itemCount,
    required double itemHeight,
    required double runSpacing,
    required double topOffset,
  }) {
    const booksPerRow = 5;
    final rowCount = (itemCount / booksPerRow).ceil();

    return List.generate(rowCount, (i) {
      final shelfTop = topOffset + (itemHeight + 22) * i; // 약간 더 촘촘하게
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
                color: AppColors.black900,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 제목/저장/선택 카운트
          Container(
            padding: const EdgeInsets.fromLTRB(12, 28, 12, 15),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '보관함',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.black900,
                      fontWeight: FontWeight.w400,
                      height: 1.1875,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (mounted) {
                            try {
                              widget.onBooksUpdated?.call(
                                updatedBooks.map((e) => Map<String, dynamic>.from(e)).toList(),
                              );
                              widget.onClose?.call();
                              Navigator.pop(context, true);
                            } catch (e) {
                              Navigator.pop(context, false);
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), // 👈 클릭 영역 확장
                          color: Colors.transparent, // 👈 배경은 투명
                          child: Text(
                            '저장',
                            style: TextStyle(
                              color: AppColors.blue500,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$selectedBookCount/9',
                        style: TextStyle(
                          color: AppColors.black900,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 상단 카운트
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 10),
                Text(
                  '$selectedBookCount/9',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.black500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 그리드
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0).copyWith(top: 21, bottom: 21),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const crossAxisCount = 5;
                  const crossAxisSpacing = 11.7;
                  const runSpacing = 35.0;
                  const itemAspectRatio = 98 / 145;
                  const topOffsetForShelf = 90.0;

                  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                  final itemWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;
                  final itemHeight = itemWidth / itemAspectRatio;

                  final rows = (updatedBooks.length / crossAxisCount).ceil();
                  final gridHeight = rows * itemHeight + (rows - 1) * runSpacing;

                  return Scrollbar(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: gridHeight + topOffsetForShelf,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            ..._buildShelves(
                              itemCount: updatedBooks.length,
                              itemHeight: itemHeight,
                              runSpacing: runSpacing,
                              topOffset: topOffsetForShelf,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: updatedBooks.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: crossAxisSpacing,
                                  mainAxisSpacing: runSpacing,
                                  childAspectRatio: itemAspectRatio,
                                ),
                                itemBuilder: (context, index) {
                                  final book = updatedBooks[index];
                                  final imageUrl = book['books']?['image'] ?? 'https://via.placeholder.com/150';
                                  final isSelected = _selected.contains(index);

                                  return GestureDetector(
                                    onTap: () => _toggleSelect(index),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(0),
                                          child: ColorFiltered(
                                            colorFilter: isSelected
                                                ? ColorFilter.mode(
                                              Colors.black.withOpacity(0.6),
                                              BlendMode.darken,
                                            )
                                                : const ColorFilter.mode(
                                              Colors.transparent,
                                              BlendMode.srcOver,
                                            ),
                                            child: BookFrame(imageUrl: imageUrl),
                                          ),
                                        ),
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
          ),
        ],
      ),
    );
  }
}