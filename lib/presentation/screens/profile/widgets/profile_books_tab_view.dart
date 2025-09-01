import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
import 'package:my_logue/core/widgets/book/book_frame.dart';
import 'package:my_logue/core/widgets/book/user_book_grid.dart';
import 'package:my_logue/data/datasources/user_book_api.dart';
import 'package:my_logue/presentation/screens/main_navigation_screen.dart';
import 'package:my_logue/presentation/screens/post/my_post_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileBooksTabView extends StatefulWidget {
  final List<Map<String, dynamic>> nonArchivedBooks;
  final String userId;

  const ProfileBooksTabView({
    super.key,
    required this.nonArchivedBooks,
    required this.userId,
  });

  @override
  State<ProfileBooksTabView> createState() => _ProfileBooksTabViewState();
}

class _ProfileBooksTabViewState extends State<ProfileBooksTabView> {
  int currentIndex = 0;
  final _api = UserBookApi(Supabase.instance.client);
  List<Map<String, dynamic>> _archivedBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchived();
  }

  Future<void> _loadArchived() async {
    try {
      final archived = await _api.fetchArchivedBooks(widget.userId);
      if (mounted) {
        setState(() {
          _archivedBooks = archived;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        const SizedBox(height: 16),
        SizedBox(
            height: null,
            child: _buildPages(),
          ),
      ],
    );
  }

  Widget _buildTabs() {
    return Material(
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('대표', 0),
          _buildTab('책장', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => currentIndex = index);
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.black500, width: 1),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.black900 : AppColors.black500,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Divider(
                  thickness: 2,
                  height: 0,
                  color: AppColors.black900,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPages() {
    return IndexedStack(
      index: currentIndex,
      children: [
        _buildRepresentativeTab(),
        _buildAllBooksTab(),
      ],
    );
  }

  Widget _buildRepresentativeTab() {
    final books = widget.nonArchivedBooks;
    if (books.isEmpty) {
      return _buildEmptyState();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: UserBookGrid(
        books: books,
        onTap: _onBookTap,
      ),
    );
  }

  Widget _buildAllBooksTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final combined = <Map<String, dynamic>>[...widget.nonArchivedBooks, ..._archivedBooks];
    if (combined.isEmpty) {
      return _buildEmptyState();
    }
    return _buildBookshelfLayout(combined);
  }

  Widget _buildBookshelfLayout(List<Map<String, dynamic>> books) {
    return LayoutBuilder(
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
            // 책들 - 양옆 22 패딩
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Wrap(
                spacing: crossAxisSpacing,
                runSpacing: 35,
                children: books.map((book) {
                  return SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: BookFrame(
                        imageUrl: book['books']?['image'] ?? '',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // 선반 - 전체 너비
            ..._buildShelves(books.length, itemHeight),
          ],
        );
      },
    );
  }

  List<Widget> _buildShelves(int bookCount, double itemHeight) {
    const booksPerRow = 5;
    final shelfCount = (bookCount / booksPerRow).ceil();

    return List.generate(shelfCount, (i) {
      final shelfY = (itemHeight + 35) * i + itemHeight;
      return Positioned(
        top: shelfY,
        left: 0,
        right: 0,
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _onBookTap(Map<String, dynamic> book) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyBookPostScreen(
          bookId: book['book_id'] as String,
          userBookId: book['id'] as String,
        ),
      ),
    );
    if (result == true && mounted) {
      // 상위에서 갱신되도록 두고, 여기서는 탭 유지만
      setState(() {});
    }
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 76),
        TextButton(
          onPressed: () async {
            final mainNavigationState = context.findAncestorStateOfType<MainNavigationScreenState>();
            if (mainNavigationState != null) {
              mainNavigationState.navigateToAddBookProfileTab();
            }
          },
          child: const Text(
            '책 추가 +',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.black900,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }
}

