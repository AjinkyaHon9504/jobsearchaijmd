// lib/pages/chatbot_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // recommended: add flutter_dotenv to load API key
import '../widgets/chat_message.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';
import '../models/resume_data.dart';

class ChatbotPage extends StatefulWidget {
  final ResumeData? initialResumeData;
  final String? uploadedFileName;
  final VoidCallback? onResumeCleared;

  const ChatbotPage({
    Key? key,
    this.initialResumeData,
    this.uploadedFileName,
    this.onResumeCleared,
  }) : super(key: key);

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ApiService _apiService = ApiService();

  String? _uploadedFileName;
  bool _isChatEnabled = false;
  bool _isProcessing = false;
  ResumeData? _resumeData;
  bool _showPinnedResume = false;

  late final GeminiService _geminiService;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();

    // Load API key from env (flutter_dotenv). If you don't use dotenv,
    // pass the API key safely when creating GeminiService.
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception(
        "❌ GEMINI_API_KEY missing — Add it in your .env file before running the app.",
      );
    }

    _geminiService = GeminiService(apiKey: apiKey.trim());

    if (widget.initialResumeData != null) {
      _resumeData = widget.initialResumeData;
      _uploadedFileName = widget.uploadedFileName;
      _isChatEnabled = true;
      _showPinnedResume = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_resumeData != null) {
          _showResumeDataSummary(_resumeData!);
          // Start a fresh Gemini chat with resume context
          try {
            _geminiService.startNewChat(_resumeData!, jobTitle: null);
          } catch (e) {
            print('Gemini start chat error: $e');
          }
        }
      });
    }
  }

  Future<void> _checkBackendHealth() async {
    try {
      bool isHealthy = await _apiService.checkHealth();
      if (!mounted) return;

      if (isHealthy) {
        print('✅ Backend is running');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Backend connected'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Backend not responding');
        _showBackendError();
      }
    } catch (e) {
      print('❌ Backend error: $e');
      if (mounted) _showBackendError();
    }
  }

  void _showBackendError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backend Not Running'),
        content: const Text(
          'The backend server is not running.\n\n'
          'Please start it with:\n'
          'cd backend\n'
          'uvicorn main:app --reload\n\n'
          'Make sure it\'s running on http://localhost:8000',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkBackendHealth();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(ChatbotPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialResumeData != null &&
        widget.initialResumeData != oldWidget.initialResumeData) {
      setState(() {
        _resumeData = widget.initialResumeData;
        _uploadedFileName = widget.uploadedFileName;
        _isChatEnabled = true;
        _showPinnedResume = true;
        _messages.clear();
      });
      _showResumeDataSummary(widget.initialResumeData!);
      // Reinitialize Gemini context
      _geminiService.startNewChat(widget.initialResumeData!, jobTitle: null);
    }
  }

  Future<void> _pickAndProcessPDF() async {
    print('📂 [ChatbotPage] Opening file picker...');

    setState(() {
      _isProcessing = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null) {
        print('❌ [ChatbotPage] User cancelled file selection');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      if (result.files.single.bytes == null) {
        print('❌ [ChatbotPage] No bytes available');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _uploadedFileName = result.files.single.name;
      });

      setState(() {
        _messages.add(
          ChatMessage(
            text: '⏳ Processing your resume... Please wait.',
            isUser: false,
          ),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Uploading and processing resume...'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );

      ResumeData resumeData;
      final bytes = result.files.single.bytes!;
      final name = result.files.single.name;
      resumeData = await _apiService.extractResumeFromBytes(bytes, name);

      print('✅ [ChatbotPage] Resume parsed successfully!');

      setState(() {
        _resumeData = resumeData;
        _isProcessing = false;
        _isChatEnabled = true;
        _showPinnedResume = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Resume processed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _showResumeDataSummary(resumeData);

      // IMPORTANT: start Gemini chat session with resume context
      try {
        _geminiService.startNewChat(resumeData, jobTitle: null);
      } catch (e) {
        print('Error starting Gemini chat: $e');
      }
    } catch (e) {
      print('❌ [ChatbotPage] Error: $e');
      setState(() {
        _isProcessing = false;
        _uploadedFileName = null;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(e.toString()),
                  const SizedBox(height: 16),
                  const Text(
                    'Troubleshooting:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Make sure backend is running:\n   uvicorn main:app --reload',
                  ),
                  const SizedBox(height: 4),
                  const Text('2. Check backend URL in api_service.dart'),
                  const SizedBox(height: 4),
                  const Text('3. Verify PDF file is not corrupted'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkBackendHealth();
                },
                child: const Text('Check Backend'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text:
                '❌ Error processing resume. Please check if the backend is running.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _showResumeDataSummary(ResumeData data) {
    String summary =
        '''
✅ Resume processed successfully!

📋 Name: ${data.contactInfo.name ?? 'Not found'}
📧 Email: ${data.contactInfo.email ?? 'Not found'}
💼 Experience: ${data.experience.totalYears} years
🎯 Skills: ${data.skills.allSkills.take(5).join(', ')}${data.skills.allSkills.length > 5 ? '...' : ''}

Suggested Job Titles:
${data.searchKeywords.jobTitles.take(3).map((t) => '• $t').join('\n')}

I'm ready to help you find jobs! What are you looking for?
''';

    setState(() {
      _messages.add(ChatMessage(text: summary, isUser: false));
    });
  }

  Widget _buildPinnedResume(ResumeData data) {
    return Dismissible(
      key: const ValueKey('pinned_resume'),
      direction: DismissDirection.up,
      onDismissed: (_) => setState(() => _showPinnedResume = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.contactInfo.name ?? 'Name not found',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Skills: ${data.skills.allSkills.take(6).join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Suggested: ${data.searchKeywords.jobTitles.take(3).join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _showPinnedResume = false),
            ),
          ],
        ),
      ),
    );
  }

  void _clearResume() {
    setState(() {
      _uploadedFileName = null;
      _isChatEnabled = false;
      _resumeData = null;
      _messages.clear();
      _showPinnedResume = false;
    });
    widget.onResumeCleared?.call();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Resume cleared')));
  }

  /// Parses incoming user chat and routes to the right handler:
  /// - "add job" or "add job title" -> adds custom job
  /// - "my new job is X" -> sets new target job and updates context
  /// - "company <name> jobs" or "jobs at <name>" -> asks Gemini for company job titles
  /// - else -> normal Gemini chat
  Future<void> _handleUserMessage(String message) async {
    final lower = message.toLowerCase().trim();

    // 1) Add custom job titles
    final addJobRegex = RegExp(
      r'^(add|save)\s+(job(?:\s+title)?\s+)?[:\-]?\s*(.+)$',
      caseSensitive: false,
    );
    final myNewJobRegex = RegExp(
      r'^(my new job (is|:))\s*(.+)$',
      caseSensitive: false,
    );
    final companyJobsRegex = RegExp(
      r'(?:(?:jobs at|company|roles at)\s+)(.+)$',
      caseSensitive: false,
    );

    // Priority: explicit "add" command
    final addMatch = addJobRegex.firstMatch(message);
    if (addMatch != null) {
      final title = addMatch.group(3)?.trim() ?? '';
      if (title.isEmpty) {
        _appendBotMessage(
          'Please tell me the job title to add, e.g. "Add Data Engineer".',
        );
        return;
      }
      // Save locally and optionally update Gemini context
      final result = await _geminiService.addCustomJobTitle(
        title,
        resume: _resumeData,
      );
      _appendBotMessage(result);
      return;
    }

    // "My new job is X" -> update target job and reset context
    final myNewJobMatch = myNewJobRegex.firstMatch(message);
    if (myNewJobMatch != null) {
      final title = myNewJobMatch.group(3)?.trim() ?? '';
      if (title.isEmpty) {
        _appendBotMessage(
          'Please provide the job title, e.g. "My new job is Product Manager".',
        );
        return;
      }
      if (_resumeData != null) {
        _geminiService.startNewChat(_resumeData!, jobTitle: title);
      }
      _appendBotMessage(
        'Target job updated to "$title". I will use this when evaluating suggestions.',
      );
      return;
    }

    // Company jobs query (e.g., "job titles in Google", "jobs at Microsoft")
    final companyMatch = companyJobsRegex.firstMatch(lower);
    if (companyMatch != null) {
      final company = companyMatch.group(1)?.trim() ?? '';
      if (company.isEmpty) {
        _appendBotMessage(
          'Please specify the company name, e.g. "Jobs at Google".',
        );
        return;
      }
      if (_resumeData == null) {
        _appendBotMessage(
          'Upload your resume first so I can evaluate suitability.',
        );
        return;
      }

      _appendBotMessage(
        'Looking up typical job titles at "$company" and evaluating them for you...',
      );
      setState(() => _isProcessing = true);
      final reply = await _geminiService.getCompanyJobTitles(
        company,
        _resumeData!,
      );
      setState(() => _isProcessing = false);
      _appendBotMessage(reply);
      return;
    }

    // Default: send message to Gemini
    setState(() => _isProcessing = true);
    final reply = await _geminiService.sendMessage(message);
    setState(() => _isProcessing = false);
    _appendBotMessage(reply);
  }

  void _appendUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
  }

  void _appendBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: false));
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    _appendUserMessage(text);

    // Don't block UI: handle asynchronously
    _handleUserMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Job Assistant'),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_uploadedFileName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                avatar: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(
                  _uploadedFileName!.length > 15
                      ? '${_uploadedFileName!.substring(0, 15)}...'
                      : _uploadedFileName!,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: _isProcessing ? null : _clearResume,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_resumeData != null && _showPinnedResume)
            _buildPinnedResume(_resumeData!),
          if (_uploadedFileName == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 80,
                      color: Colors.blue.shade300,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Upload Your Resume',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Upload your resume to activate the AI assistant',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickAndProcessPDF,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(
                        _isProcessing ? 'Processing...' : 'Upload Resume (PDF)',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _checkBackendHealth,
                      icon: const Icon(Icons.health_and_safety, size: 16),
                      label: const Text('Check Backend Connection'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) => _messages[index],
              ),
            ),
          if (_isChatEnabled && !_isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText:
                            'Ask about jobs (e.g., "Add Data Engineer", "Jobs at Google")',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    mini: true,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
