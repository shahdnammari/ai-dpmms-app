import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/auth_gate.dart';
import 'services/notification_service.dart';

// ADD THIS: Navigator key for notifications
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize NotificationService with navigatorKey
  await NotificationService.instance.init(navKey: navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Brand colors: Tech + Professional
  static const Color kPrimary = Color(0xFF4F5DFF); // Indigo Blue
  static const Color kAccent = Color(0xFF8B5CF6);  // Purple
  static const Color kBg = Color(0xFFF6F7FB);      // App background

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,

      // Global Font
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme(),
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.light,
        primary: kPrimary,
        secondary: kAccent,
        surface: Colors.white,
      ),

      scaffoldBackgroundColor: kBg,

      // AppBar
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 3,
        color: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),

      // TextFields (Search and etc...)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 1.6),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      // Checkbox look
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: Colors.grey.shade400),
      ),

      // Bottom NavigationBar default styling
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: kPrimary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? kPrimary : Colors.grey.shade600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? kPrimary : Colors.grey.shade600,
            size: 24,
          );
        }),
      ),
    );

    return MaterialApp(
      title: 'AI-DPMMS',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // ADD NAVIGATOR KEY HERE
      navigatorKey: navigatorKey,
      home: const AuthGate(),
    );
  }
}