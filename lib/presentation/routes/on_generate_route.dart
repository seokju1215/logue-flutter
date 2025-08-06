import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/models/book_post_model.dart';
import '../screens/book/book_detail_screen.dart';
import '../screens/home/search/search_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/post/edit_review_screen.dart';
import '../screens/post/my_post_screen.dart';
import '../screens/add_book/search_book_screen.dart';
import '../screens/profile/notification_screen.dart';
import '../screens/profile/other_profile_screen.dart';
import '../screens/profile/profile_edit/bio_edit.dart';
import '../screens/profile/profile_edit/delete_accout_screen.dart';
import '../screens/profile/profile_edit/job_edit.dart';
import '../screens/profile/profile_edit/name_edit.dart';
import '../screens/profile/profile_edit/profile_edit_screen.dart';
import '../screens/profile/profile_edit/username_edit.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/signup/login_screen.dart';
import '../screens/signup/select_3books_screen.dart';
import '../screens/signup/term_screen.dart';
import '../screens/splash_screen.dart';

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  print('🧭 [onGenerateRoute] name: ${settings.name}');
  print('📦 [onGenerateRoute] arguments: ${settings.arguments}');
  final args = settings.arguments;

  // 딥링크 fragment에 refresh_token이 있으면 세션 복구
  if (settings.name != null && settings.name!.contains('#')) {
    final uri = Uri.parse(settings.name!);
    if (uri.fragment.isNotEmpty) {
      final params = Uri.splitQueryString(uri.fragment);
      final refreshToken = params['refresh_token'];
      if (refreshToken != null) {
        // 동기적으로 처리할 수 없으므로 SplashScreen에서 복구하도록 arguments로 전달
        return MaterialPageRoute(
          builder: (_) => SplashScreen(refreshToken: refreshToken),
        );
      }
    }
  }

  switch (settings.name) {
    case '/main':
      final map = args as Map<String, dynamic>? ?? {};
      print('🧭 실제 전달된 arguments map: $map');
      return MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          initialTabIndex: map['initialTabIndex'] ?? 0,
          goToMyBookPostScreen: map['goToMyBookPostScreen'] ?? false,
        ),
      );

    case '/main/profile':
      MainNavigationScreen.lastSelectedIndex = 1;
      return MaterialPageRoute(
        builder: (_) => MainNavigationScreen(goToMyBookPostScreen: false),
      );

    case '/main/search':
      final map = args as Map<String, dynamic>? ?? {};
      final index = map['initialIndex'] ?? 0;
      MainNavigationScreen.lastSelectedIndex = index;
      return MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          child: SearchScreen(),
          goToMyBookPostScreen: false,
        ),
      );

    case '/splash':
      return MaterialPageRoute(builder: (_) => const SplashScreen());

    case '/login':
      return MaterialPageRoute(builder: (_) => const LoginScreen());

    case '/login_blocked':
      return MaterialPageRoute(builder: (_) => const LoginScreen(blocked: true));

    case '/terms':
      return MaterialPageRoute(builder: (_) => const TermsScreen());

    case '/select-3books':
      return MaterialPageRoute(builder: (_) => const Select3BooksScreen());

    case '/notification':
      return MaterialPageRoute(builder: (_) => const NotificationScreen());

    case '/search_book':
      return MaterialPageRoute(builder: (_) => const SearchBookScreen());

    case '/profile':
      return MaterialPageRoute(builder: (_) => const ProfileScreen());

    case '/delete_account_screen':
      return MaterialPageRoute(builder: (_) => const DeleteAccountScreen());

    case '/other_profile':
      final userId = args as String;
      return MaterialPageRoute(builder: (_) => OtherProfileScreen(userId: userId));

    case '/profile_edit':
      final map = args as Map<String, dynamic>;
      return MaterialPageRoute(builder: (_) => ProfileEditScreen(initialProfile: map));

    case '/username_edit':
      final map = args as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => UserNameEdit(currentUsername: map['username'] ?? ''),
      );

    case '/name_edit':
      final map = args as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => NameEdit(currentName: map['currentName'] ?? ''),
      );

    case '/job_edit':
      final map = args as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => JobEdit(currentJob: map['currentJob'] ?? ''),
      );

    case '/bio_edit':
      final map = args as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => BioEdit(currentBio: map['currentBio'] ?? ''),
      );

    case '/my_post_screen':
      final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
      return MaterialPageRoute(
        builder: (_) => MyBookPostScreen(
          bookId: map['bookId'] as String?,
          userId: map['userId'] as String?,
        ),
      );

    case '/edit_post_screen':
      return MaterialPageRoute(
        builder: (_) => EditReviewScreen(post: args as BookPostModel),
      );

    case '/book_detail':
      return MaterialPageRoute(
        builder: (_) => BookDetailScreen(bookId: args as String),
      );

    default:
      return null;
  }
}