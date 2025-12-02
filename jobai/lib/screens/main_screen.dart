import 'package:flutter/material.dart';
import 'chatbot_page.dart';
import 'dashboard_page.dart';
import '../models/resume_data.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  ResumeData? _uploadedResume;
  String? _uploadedFileName;

  void _onResumeUploaded(ResumeData resumeData, String? fileName) {
    setState(() {
      _uploadedResume = resumeData;
      _uploadedFileName = fileName;
      _selectedIndex = 0; // Switch to Chatbot tab
    });
  }

  void _onResumeCleared() {
    setState(() {
      _uploadedResume = null;
      _uploadedFileName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          ChatbotPage(
            key: ValueKey(
              'chatbot-${_uploadedResume?.contactInfo.email ?? "empty"}',
            ),
            initialResumeData: _uploadedResume,
            uploadedFileName: _uploadedFileName,
            onResumeCleared: _onResumeCleared,
          ),
          DashboardPage(
            key: ValueKey(
              'dashboard-${_uploadedResume?.contactInfo.email ?? "empty"}',
            ),
            onUpload: _onResumeUploaded,
            resumeData: _uploadedResume, // Pass resume data to fetch jobs
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chatbot',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
