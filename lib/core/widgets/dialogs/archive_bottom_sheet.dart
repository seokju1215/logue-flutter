import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/themes/stroke_text_style.dart';

class ArchiveBottomSheet extends StatefulWidget {
  final Function(bool)? onClose; // 닫기 콜백, 결과값 전달
  
  const ArchiveBottomSheet({
    super.key,
    this.onClose,
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
                      '9/9',
                      style: const TextStyle(fontSize: 12, color: AppColors.black500, height: 1.25),
                    ),
                  ],
                ),
                SizedBox(height: 8,),
              ],
            ),
          ),
          
          // 보관함 탭의 LayoutBuilder 디자인을 그대로 복사
          SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.fromLTRB(0, 21, 0, 21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 22),
                  child: StrokeTextStyle.createStrokeText(
                    text: "읽었던 책들을 간편하게 정리해보세요.", 
                    fontSize: 16, 
                    fontWeight: FontWeight.w400, 
                    color: AppColors.black900
                  )
                ),
                const SizedBox(height: 13),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 21),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: 책 추가 로직 구현
                            print('책 추가 버튼 클릭됨');
                          },
                          style: ButtonStyle(
                            foregroundColor: MaterialStateProperty.all(AppColors.black900),
                            backgroundColor: MaterialStateProperty.all(Colors.white),
                            overlayColor: MaterialStateProperty.resolveWith<Color?>(
                              (states) {
                                if (states.contains(MaterialState.pressed)) {
                                  return AppColors.black100;
                                }
                                return null;
                              },
                            ),
                            side: MaterialStateProperty.all(
                              const BorderSide(color: AppColors.black500, width: 1),
                            ),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            ),
                            padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(horizontal: 9),
                            ),
                            minimumSize: MaterialStateProperty.all(
                              const Size(0, 34),
                            ),
                            textStyle: MaterialStateProperty.all(
                              const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                height: 1.0,
                              ),
                            ),
                          ),
                          child: const Text(
                            '책 추가 +',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.black900,
                                height: 1.25),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 19),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '책을 길게 눌러 위치를 변경할 수 있어요.',
                        style: TextStyle(fontSize: 12, color: AppColors.black500),
                      ),
                      Text(
                        '0권', // TODO: 실제 책 개수로 변경
                        style: const TextStyle(fontSize: 12, color: AppColors.black500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const crossAxisCount = 5;
                    const crossAxisSpacing = 11.7;
                    const itemAspectRatio = 98 / 145;
                    const bookPadding = 22.0;

                    final availableWidth = constraints.maxWidth - (bookPadding * 2);
                    final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
                    final itemWidth = (availableWidth - totalSpacing) / crossAxisCount;
                    final itemHeight = itemWidth / itemAspectRatio;

                    return Stack(
                      children: [
                        // Stack의 최소 너비 확보용
                        SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                            child: Container(
                              // TODO: 실제 책 목록을 여기에 표시
                              height: itemHeight * 2, // 임시 높이
                              decoration: BoxDecoration(
                                color: AppColors.black100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '보관함에서 프로필에 추가할 책을 선택할 수 있습니다.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.black500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 책장 선들 (임시로 2개만 표시)
                        Positioned(
                          top: 90,
                          left: 0,
                          right: 0,
                          child: Container(
                            width: double.infinity,
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
                        ),
                        Positioned(
                          top: 90 + itemHeight + 35,
                          left: 0,
                          right: 0,
                          child: Container(
                            width: double.infinity,
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
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
