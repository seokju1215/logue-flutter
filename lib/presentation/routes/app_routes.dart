import 'package:flutter/material.dart';
import '../screens/signup/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/signup/term_screen.dart';
import '../screens/signup/select_3books_screen.dart';
import '../screens/splah_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/profile_edit_screen.dart';
import '../screens/add_book_screen.dart';
import '../screens/main_navigation_screen.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/main' : (context) => const MainNavigationScreen(),
  '/splash' : (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/terms': (context) => const TermsScreen(),
  '/select-3books' : (context) => const Select3BooksScreen(),
  '/notification' : (context)=> const NotificationScreen(),
  '/profile_edit' : (context) => const ProfileEditScreen(),
  '/add_book_screen' : (context) => const AddBookScreen(),
};