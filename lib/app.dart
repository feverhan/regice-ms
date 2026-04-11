import 'package:flutter/material.dart';

import 'pages/home_page.dart';

class FridgeInventoryApp extends StatelessWidget {
  const FridgeInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF166534)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
