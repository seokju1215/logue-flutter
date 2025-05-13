import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logue/presentation/screens/signup/select_3books_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // ✅ .env 등록 추가

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Select3BooksScreen(),
  ));
}