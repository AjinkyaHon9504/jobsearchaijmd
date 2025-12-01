import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'app_globals.dart';

void main() {
  runApp(const JobPostingApp());
}

class JobPostingApp extends StatelessWidget {
  const JobPostingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey, // Important!
      home: const MainScreen(),
    );
  }
}