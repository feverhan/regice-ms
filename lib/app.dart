import 'package:flutter/material.dart';

import 'pages/home_page.dart';

class FridgeInventoryApp extends StatelessWidget {
  const FridgeInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF3E6B57);
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light),
      useMaterial3: true,
    );

    return MaterialApp(
      title: '鲜度管家',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF6F2EA),
        visualDensity: VisualDensity.compact,
        textTheme: baseTheme.textTheme.copyWith(
          headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: const Color(0xFF1F3128),
          ),
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: const Color(0xFF1F3128),
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: const Color(0xFF24362D),
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            height: 1.45,
            color: const Color(0xFF2B3A33),
          ),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.4,
            color: const Color(0xFF44534C),
          ),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.35,
            color: const Color(0xFF65746C),
          ),
          labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: baseTheme.textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F2EA),
          foregroundColor: Color(0xFF203128),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Color(0xFF203128),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE8E1D4)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Color(0xFFFFFCF7),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFE1D8C9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFFE1D8C9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Color(0xFF6A8A76), width: 1.4),
          ),
          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF859289)),
          labelStyle: TextStyle(fontSize: 13, color: Color(0xFF5A675F)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: const BorderSide(color: Color(0xFFD6CEC0)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF355C49),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF355C49),
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: const Color(0xFFFFFCF7),
          indicatorColor: const Color(0xFFDCE7DE),
          labelTextStyle: MaterialStateProperty.resolveWith<TextStyle?>(
            (states) => TextStyle(
              fontSize: states.contains(MaterialState.selected) ? 12.5 : 12,
              fontWeight: states.contains(MaterialState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(MaterialState.selected)
                  ? const Color(0xFF284235)
                  : const Color(0xFF6A776F),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
