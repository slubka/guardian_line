import 'package:flutter/material.dart';
import 'screens/call_screen.dart';

void main() {
  runApp(const GuardianLineApp());
}

class GuardianLineApp extends StatelessWidget {
  const GuardianLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardianLine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const CallScreen(),
    );
  }
}