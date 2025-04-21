import 'package:flutter/material.dart';
import '../screens/signup/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/signup/term_screen.dart';
import '../screens/signup/select_3books_screen.dart';
import '../screens/splah_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/profile_edit_screen.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/splash' : (context) => const SplashScreen(),
  '/login': (context) => const LoginScreen(),
  '/home' : (context) => const HomeScreen(),
  '/terms': (context) => const TermsScreen(),
  '/select-3books' : (context) => const Select3BooksScreen(),
  '/profile' : (context) => const ProfileScreen(),
  '/notification' : (context)=> const NotificationScreen(),
  '/profile_edit' : (context) => const ProfileEditScreen(),
};