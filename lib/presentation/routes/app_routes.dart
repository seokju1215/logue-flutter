import 'package:flutter/material.dart';
import '../../data/models/book_post_model.dart';
import '../../domain/entities/follow_list_type.dart';
import '../screens/post/edit_review_screen.dart';
import '../screens/profile/follow_list_screen.dart';
import '../screens/signup/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/signup/term_screen.dart';
import '../screens/signup/select_3books_screen.dart';
import '../screens/splah_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/notification_screen.dart';
import '../screens/profile/profile_edit/profile_edit_screen.dart';
import '../screens/profile/add_book/add_book_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/profile/profile_edit/bio_edit.dart';
import '../screens/profile/profile_edit/job_edit.dart';
import '../screens/profile/profile_edit/name_edit.dart';
import '../screens/profile/profile_edit/username_edit.dart';
import '../screens/profile/add_book/search_book_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/post/my_post_screen.dart';
import '../screens/home/search/search_screen.dart';
import 'package:logue/presentation/screens/profile/other_profile_screen.dart';


Map<String, WidgetBuilder> appRoutes = {
  '/main' : (context) => const MainNavigationScreen(),
  '/main/profile': (context) => const MainNavigationScreen(initialIndex: 1),
  '/splash' : (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/terms': (context) => const TermsScreen(),
  '/select-3books' : (context) => const Select3BooksScreen(),
  '/notification' : (context)=> const NotificationScreen(),
  '/add_book_screen' : (context) => const AddBookScreen(),
  '/login_blocked': (context) => const LoginScreen(blocked: true),
  '/search_book' : (context) => const SearchBookScreen(),
  '/profile' : (context) => const ProfileScreen(),
  '/search' : (context) => const SearchScreen(),
  '/other_profile': (context) {
    final userId = ModalRoute.of(context)!.settings.arguments as String;
    return OtherProfileScreen(userId: userId);
  },

  //profile_edit
  '/profile_edit': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return ProfileEditScreen(initialProfile: args);
  },
  '/username_edit': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final currentUsername = args['username'] ?? '';
    return UserNameEdit(currentUsername: currentUsername);
  },
  '/name_edit': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final currentName = args['currentName'] ?? '';
    return NameEdit(currentName: currentName);
  },
  '/job_edit': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final currentJob = args['username'] ?? '';
    return JobEdit(currentJob: currentJob);
  },
  '/bio_edit': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final currentBio = args['currentBio'] ?? '';
    return BioEdit(currentBio: currentBio);

  },
  '/my_post_screen': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final bookId = args['bookId'] as String;
    final userId = args['userId'] as String?;
    return MyBookPostScreen(
      bookId: bookId,
      userId: userId,
    );
  },

  '/edit_post_screen': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as BookPostModel;
    return EditReviewScreen(post: args);
  },






};