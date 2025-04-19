import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/term_screen.dart';

Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const LoginScreen(),
  '/home' : (context) => const HomeScreen(),
  '/terms': (context) => TermsScreen(),
};