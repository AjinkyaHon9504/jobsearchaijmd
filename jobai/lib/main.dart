import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'app_globals.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const JobPostingApp());
}

class JobPostingApp extends StatelessWidget {
  const JobPostingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Job Finder',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey, // Important!
      home: const MainScreen(),
    );
  }
}
