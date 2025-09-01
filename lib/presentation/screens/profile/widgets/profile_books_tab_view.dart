import 'package:flutter/material.dart';
import 'package:my_logue/core/themes/app_colors.dart';
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
    return UserBookGrid(
      books: books,
      onTap: _onBookTap,
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
    return UserBookGrid(
      books: combined,
      onTap: _onBookTap,
    );
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

