import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/data/models/book_model.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import '../../../data/services/book_activity_analytics_service.dart';
import '../../../data/utils/firebase_analytics_util.dart';
import '../../../data/datasources/user_book_api.dart';
import 'dart:ui';

class WriteReviewScreen extends StatefulWidget {
  final BookModel book;
  final String fromTab; // 'profile' 또는 'archive'

  const WriteReviewScreen({Key? key, required this.book, required this.fromTab}) : super(key: key);

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  OverlayEntry? _loadingOverlay;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final client = Supabase.instance.client;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      final text = _titleController.text;
      
      // 줄바꿈이 2줄을 넘으면 마지막 줄바꿈 이후의 텍스트 제거
      final newlineCount = '\n'.allMatches(text).length;
      if (newlineCount > 1) {
        // 첫 번째 줄바꿈의 위치 찾기
        final firstNewlineIndex = text.indexOf('\n');
        if (firstNewlineIndex != -1) {
          // 첫 번째 줄바꿈 이후의 모든 텍스트 제거
          _titleController.value = TextEditingValue(
            text: text.substring(0, firstNewlineIndex + 1),
            selection: TextSelection.collapsed(offset: firstNewlineIndex + 1),
          );
          return;
        }
      }
      
      // 제목이 50자를 넘으면 자동으로 잘라내기
      if (text.length > 50) {
        _titleController.value = TextEditingValue(
          text: text.substring(0, 50),
          selection: TextSelection.collapsed(offset: 50),
        );
      }
      setState(() {});
    });
    _contentController.addListener(() {
      // 내용이 2000자를 넘으면 자동으로 잘라내기
      if (_contentController.text.length > 2000) {
        _contentController.value = TextEditingValue(
          text: _contentController.text.substring(0, 2000),
          selection: TextSelection.collapsed(offset: 2000),
        );
      }
      setState(() {});
    });
  }
  void _showLoadingOverlay() {
    if (_loadingOverlay != null) return; // 중복 방지
    _loadingOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 전체 화면 블러 + 딤 + 터치 차단
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          ),
          // 중앙 로딩
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      ),
    );

    // rootOverlay: true 로 최상단에 삽입 (앱 전체 덮도록)
    Overlay.of(context, rootOverlay: true)?.insert(_loadingOverlay!);
  }

  void _hideLoadingOverlay() {
    _loadingOverlay?.remove();
    _loadingOverlay = null;
  }

  @override
  void dispose() {
    _hideLoadingOverlay();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveReview() async {
    if (_isSaving) return;
    final user = client.auth.currentUser;
    if (user == null) return;

    final reviewTitle = _titleController.text.trim();
    final reviewContent = _contentController.text.trim();

    if (reviewTitle.length > 50 || reviewContent.length > 2000) return;

    setState(() => _isSaving = true);
    _showLoadingOverlay();

    try {
      String? bookId;

      if (widget.book.isbn.isNotEmpty) {
        final existingByIsbn = await client
            .from('books')
            .select('id')
            .eq('isbn', widget.book.isbn)
            .maybeSingle();
        if (existingByIsbn != null) bookId = existingByIsbn['id'];
      }

      if (bookId == null) {
        final existingByInfo = await client
            .from('books')
            .select('id')
            .eq('title', widget.book.title)
            .eq('author', widget.book.author)
            .maybeSingle();
        if (existingByInfo != null) bookId = existingByInfo['id'];
      }

      if (bookId == null) {
        print("api ${widget.book.link}");
        final inserted = await client
            .from('books')
            .insert({
          'isbn': widget.book.isbn,
          'title': widget.book.title,
          'subtitle': widget.book.subtitle ?? '',
          'author': widget.book.author,
          'publisher': widget.book.publisher,
          'published_date': widget.book.publishedDate,
          'page_count': widget.book.pageCount,
          'description': widget.book.description,
          'toc': widget.book.toc,
          'image': widget.book.image,
          'link': widget.book.link,
        })
            .select('id')
            .maybeSingle();
        bookId = inserted?['id'];
      }

      if (bookId == null) throw Exception('책 ID를 확보할 수 없습니다.');

              // fromTab에 따라 다르게 처리
        if (widget.fromTab == 'profile') {
          // 프로필 탭에서 추가: is_archived = false
          final FunctionResponse response = await client.functions.invoke('add-user-book-v2', body: {
            'user_id': user.id,
            'book_id': bookId,
            'isbn': widget.book.isbn,
            'review_title': reviewTitle,
            'review_content': reviewContent,
            'is_archived': false,
          });
          
          if (response.status != 200) {
            final errorMessage = response.data['error'] ?? '알 수 없는 오류';
            debugPrint('❌ 함수 오류: $errorMessage');
            throw Exception(errorMessage);
          }
        } else {
          // 보관함 탭에서 추가: is_archived = true, archived_order_index = 0
          final FunctionResponse response = await client.functions.invoke('add-user-book-v2', body: {
            'user_id': user.id,
            'book_id': bookId,
            'isbn': widget.book.isbn,
            'review_title': reviewTitle,
            'review_content': reviewContent,
            'is_archived': true,
          });
          
          if (response.status != 200) {
            final errorMessage = response.data['error'] ?? '알 수 없는 오류';
            debugPrint('❌ 함수 오류: $errorMessage');
            throw Exception(errorMessage);
          }
        }

      // 책 추가 및 리뷰 작성 트래킹
        FirebaseAnalyticsUtil.logBookAdd(bookTitle: widget.book.title, bookId: bookId);
        FirebaseAnalyticsUtil.logReviewWrite(bookTitle: widget.book.title, bookId: bookId);
      
      // Firebase Analytics 트래킹 (신규 책을 보관함에 추가)
      await FirebaseAnalyticsUtil.logBookAddedToArchive(
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author ?? '',
        reviewTitle: _titleController.text.trim(),
        reviewContent: _contentController.text.trim(),
        rating: 5, // 기본값 (실제 평점 시스템이 있다면 해당 값 사용)
      );
      
      // 통계 서비스에 카운트 추가
      await BookActivityAnalyticsService.trackBookAdded();
      await BookActivityAnalyticsService.trackReviewWritten();

      if (!mounted) return;

      // SearchBookScreen과 WriteReviewScreen 닫기
      Navigator.pop(context);

      // fromTab에 따라 해당 탭으로 돌아가기
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // AddBookScreen으로 돌아가서 새로고침
          Navigator.of(context).pop(true);
        }
      });

    } catch (e) {
      debugPrint('❌ 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      _hideLoadingOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/back_arrow.svg'),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          '책 추가',
          style: TextStyle(fontSize: 16, color: AppColors.black900, fontWeight: FontWeight.w500,),
        ),
        actions: [
          TextButton(
            onPressed: (_isSaving || 
                        _titleController.text.length > 50 || 
                        _contentController.text.length > 2000) 
                        ? null 
                        : _saveReview,
            child: Text(
              '확인',
              style: TextStyle(
                color: (_isSaving || 
                        _titleController.text.length > 50 || 
                        _contentController.text.length > 2000)
                        ? AppColors.black300
                        : const Color(0xFF0055FF),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SizedBox(
                        width: 235,
                        height: 349,
                        child: BookFrame(imageUrl: widget.book.image),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: const Text('후기 제목',
                              style: TextStyle(fontSize: 12, color: AppColors.black500)),
                        ),
                        Text(
                          '${_titleController.text.length}/50',
                          style: const TextStyle(fontSize: 12, color: AppColors.black500),
                        ),
                      ],
                    ),
                    TextField(
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      controller: _titleController,
                      maxLength: 50,
                      maxLines: 2, // 최대 2줄까지만
                      keyboardType: TextInputType.multiline,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                        // 두 번째 줄바꿈(\n)부터 차단
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final oldText = oldValue.text;
                          final newText = newValue.text;
                          
                          // 기존 줄바꿈 개수
                          final oldLineCount = '\n'.allMatches(oldText).length;
                          // 새로운 줄바꿈 개수
                          final newLineCount = '\n'.allMatches(newText).length;
                          
                          // 이미 1개의 줄바꿈(2줄)이 있고, 새로 추가된 텍스트에 줄바꿈이 있으면 차단
                          if (oldLineCount >= 1 && newLineCount > oldLineCount) {
                            return oldValue; // 두 번째 줄바꿈부터 입력 차단
                          }
                          
                          return newValue;
                        }),
                      ],
                      style: const TextStyle(fontSize: 14, color: AppColors.black900),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 9),
                          child: const Text('후기 내용',
                              style: TextStyle(fontSize: 12, color: AppColors.black500)),
                        ),
                        Text(
                          '${_contentController.text.length}/2000',
                          style: const TextStyle(fontSize: 12, color: AppColors.black500),
                        ),
                      ],
                    ),
                    TextField(
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      controller: _contentController,
                      maxLength: 2000,
                      minLines: 3,
                      maxLines: null,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(2000),
                      ],
                      style: const TextStyle(fontSize: 14, color: AppColors.black900),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}