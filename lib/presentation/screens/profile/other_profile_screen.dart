import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logue/core/themes/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logue/data/datasources/user_book_api.dart';
import 'package:logue/domain/usecases/get_user_books.dart';
import 'package:logue/core/widgets/book/user_book_grid.dart';

class OtherProfileScreen extends StatefulWidget {
  final String userId;
  const OtherProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  final client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  Map<String, dynamic>? profile;
  late final GetUserBooks _getUserBooks;
  List<Map<String, dynamic>> books = [];

  @override
  void initState() {
    super.initState();
    _getUserBooks = GetUserBooks(UserBookApi(client));
    _fetchProfile();
    _loadBooks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
    });
  }

  void _checkIfScrollable() {
    if (!_scrollController.hasClients) return;
    final isNowScrollable = _scrollController.position.maxScrollExtent > 0;
    if (mounted && isNowScrollable != _isScrollable) {
      setState(() => _isScrollable = isNowScrollable);
    }
  }

  Future<void> _fetchProfile() async {
    final data = await client.from('profiles').select().eq('id', widget.userId).single();
    setState(() => profile = data);
  }

  Future<void> _loadBooks() async {
    final result = await _getUserBooks(widget.userId);
    result.sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
    setState(() => books = result);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollable();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(profile?['username'] ?? '사용자', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: SvgPicture.asset('assets/share_icon.svg'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              if (books.isNotEmpty)
                _buildBookGrid()
              else ...[
                const SizedBox(height: 95),
                const Center(
                  child: Text(
                    '책이 아직 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.black500),
                  ),
                ),
                const SizedBox(height: 90),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = profile?['avatar_url'] ?? 'basic';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?['name'] ?? '', style: Theme.of(context).textTheme.bodyLarge),
                  Text(profile?['job'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Text(profile?['bio'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.black900)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Container(
              width: 71,
              height: 71,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black100, width: 1),
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundImage: avatarUrl == 'basic' ? null : NetworkImage(avatarUrl),
                child: avatarUrl == 'basic'
                    ? Image.asset('assets/basic_avatar.png', width: 70, height: 70)
                    : null,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildCount("팔로워", profile?['followers'] ?? 0),
            const SizedBox(width: 24),
            _buildCount("팔로잉", profile?['followings'] ?? 0),
          ],
        ),
      ],
    );
  }

  Widget _buildBookGrid() {
    return UserBookGrid(
      books: books,
      onTap: (book) {
        final bookId = book['id'] as String;
        Navigator.pushNamed(context, '/my_post_screen', arguments: {'bookId': bookId});
      },
    );
  }

  Widget _buildCount(String label, int count) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.black500)),
        Text('$count', style: const TextStyle(fontSize: 12, color: AppColors.black500)),
      ],
    );
  }
}