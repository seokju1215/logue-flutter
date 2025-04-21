import 'package:flutter/material.dart';
import '../screens/signup/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/signup/term_screen.dart';
import '../screens/signup/select_3books_screen.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const LoginScreen(),
  '/home' : (context) => const HomeScreen(),
  '/terms': (context) => const TermsScreen(),
  '/select-3books' : (context) => const Select3BooksScreen(),
};